#!/bin/bash
##
## Script to back up to a mount point destination 
## existing persistent volumes in OpenShift from Gluster/RHOCS
##

## Environment variables .ini file should be provided as argument
if [ $1 -a -f $1 ]
then 
  source $1
else
  echo "Error: You have to provide a ini file with environment variables as a parameter
"
  echo "Example: `basename $0` myvars.ini"
  exit 1
fi 

## Temporary file to put the list of Gluster file volumes to backup
VOLLIST=$VOLDIR/vollist-`date +%Y%m%d-%H%M`.txt 

## Temporary file to put the list of Gluster block volumes to backup
VOLBLOCKLIST=$VOLDIR/volblocklist-`date +%Y%m%d-%H%M`.txt 

## Provides Logging of this script in the dir specified below:
LOG="${LOGDIR}/`basename $0`-`date +%Y%m%d-%H%M`.log"
exec &>> $LOG

BASTIONHOST=localhost

## Source and destination of backups
PARENTMOUNT=$PARENTDIR/backup-`date +%Y%m%d-%H%M`  ## Parent directory for all volumes mounting (if you want incremental backup working, remove date command)
/usr/bin/mkdir $PARENTMOUNT
TARGET=$DESTINATION/backup-`date +%Y%m%d-%H%M` ## Daily/Hourly destination of backups

## Get list of Persistent Volumes in Gluster with Heketi till now and 
## store them in file $VOLLIST , exclude gluster-block and heketidb
/usr/bin/heketi-cli volume list --server $HEKETI_CLI_SERVER --user $USERHEKETI --secret $SECRETHEKETI | /usr/bin/grep -v block | /usr/bin/grep -v heketidbstorage | /usr/bin/cut -d":" -f4 > $VOLLIST

## Get list of gluster-block host volumes in Gluster with Heketi till now 
## and store them in file $VOLBLOCKLIST 
/usr/bin/heketi-cli volume list --server $HEKETI_CLI_SERVER --user $USERHEKETI --secret $SECRETHEKETI | /usr/bin/grep "\[block\]" | /usr/bin/cut -d":" -f4 | /usr/bin/cut -d"[" -f1 | tr -d " " > $VOLBLOCKLIST

## If converged mode, get name of gluster pod
if [ "$RHOCSMODE" = "converged" ]
then 
  ## Get inside OCP cluster to get access of Gluster pod
  /usr/bin/ssh $BASTIONHOST "/usr/bin/oc login $OCADDRESS -u $OCUSER -p $OCPASS"
  POD=`/usr/bin/ssh $BASTIONHOST "/usr/bin/oc get pods --all-namespaces -o wide" | /usr/bin/grep glusterfs | /usr/bin/grep $GLUSTERSERVER | /usr/bin/tr -s " " | /usr/bin/cut -f2 -d" "`
  echo $POD
  /usr/bin/ssh $BASTIONHOST "/usr/bin/oc project $OCPROJECT"
fi

/usr/bin/mkdir $TARGET

## Gluster-file backup section ###
## For each volume in $VOLLIST create mount directory, mount it,
## and copy to destination (and umount)
for VOLNAME in `/usr/bin/cat $VOLLIST`
do
  ## Create an specific name for snapshot with controlled timestamp
  SNAPNAME=${VOLNAME}-snap-`date +%Y%m%d-%H%M`
  ## Create a dir to mount Gluster Snapshot based on Snapshot name
  /usr/bin/mkdir -p $PARENTMOUNT/$SNAPNAME
  ## Create a one-off snapshot of Gluster volume to be used for backup. 
  ## Depending on deployment mode: set of actions to interact with 
  ## Gluster commands is different:
  if [ "$RHOCSMODE" = "converged" ]
  then 
    ## Create snpashot and activate for VOLNAME  
    /usr/bin/ssh $BASTIONHOST "/usr/bin/oc rsh $POD /usr/sbin/gluster snapshot create $SNAPNAME $VOLNAME no-timestamp"
    /usr/bin/ssh $BASTIONHOST "/usr/bin/oc rsh $POD /usr/sbin/gluster snapshot activate $SNAPNAME"
  elif [ "$RHOCSMODE" = "independent" ]
  then
    ## Create snpashot and activate for VOLNAME 
    /usr/bin/ssh $GLUSTERSERVER "/usr/sbin/gluster snapshot create $SNAPNAME $VOLNAME no-timestamp"
    /usr/bin/ssh $GLUSTERSERVER "/usr/sbin/gluster snapshot activate $SNAPNAME"
  else
    echo "Error: parameter RHOCSMODE not set to converged or independent"
    exit 1
  fi

  /usr/bin/mount -t glusterfs $GLUSTERSERVER:/snaps/$SNAPNAME/$VOLNAME $PARENTMOUNT/$SNAPNAME
  echo "Backing up $SNAPNAME ..."
  /usr/bin/mkdir -p $TARGET
  /usr/bin/tar czf $TARGET/$SNAPNAME.tar.gz $PARENTMOUNT/$SNAPNAME/
  /usr/bin/umount $PARENTMOUNT/$SNAPNAME
  ## Depending on deployment mode: set of actions to interact with
  ## Gluster commands is different:
  if [ "$RHOCSMODE" = "converged" ]
  then 
    ## Delete Snapshot  
    /usr/bin/ssh $BASTIONHOST "/usr/bin/oc rsh $POD /usr/sbin/gluster snapshot delete $SNAPNAME"<<EOF
y
EOF
  fi
  if [ "$RHOCSMODE" = "independent" ]
  then
    ## Delete Snapshot
    /usr/bin/ssh $GLUSTERSERVER "/usr/sbin/gluster snapshot delete $SNAPNAME"<<EOF
y
EOF
  fi
  echo "Dismounting and deleting $SNAPNAME ..."
done

## Gluster-block backup section ###
## For each host volume in $VOLBLOCKLIST create mount directory, mount it,
## mount loop each block-volume inside it
## and copy to destination (and umount)
for VOLBLOCKNAME in `/usr/bin/cat $VOLBLOCKLIST`
do
  ## Create an specific name for snapshot with controlled timestamp
  SNAPBLOCKNAME=${VOLBLOCKNAME}-snap-`date +%Y%m%d-%H%M`
  ## Create a dir to mount Gluster Snapshot based on Snapshot name
  /usr/bin/mkdir -p $PARENTMOUNT/$SNAPBLOCKNAME
  ## Create a one-off snapshot of Gluster volume to be used for backup. 
  ## Depending on deployment mode: set of actions to interact with 
  ## Gluster commands is different:
  if [ "$RHOCSMODE" = "converged" ]
  then 
    ## Create snapshot and activate for VOLBLOCKNAME  
    /usr/bin/ssh $BASTIONHOST "/usr/bin/oc rsh $POD /usr/sbin/gluster snapshot create $SNAPBLOCKNAME $VOLBLOCKNAME no-timestamp"
    /usr/bin/ssh $BASTIONHOST "/usr/bin/oc rsh $POD /usr/sbin/gluster snapshot activate $SNAPBLOCKNAME"
  elif [ "$RHOCSMODE" = "independent" ]
  then
    ## Create snpashot and activate for VOLBLOCKNAME 
    /usr/bin/ssh $GLUSTERSERVER "/usr/sbin/gluster snapshot create $SNAPBLOCKNAME $VOLBLOCKNAME no-timestamp"
    /usr/bin/ssh $GLUSTERSERVER "/usr/sbin/gluster snapshot activate $SNAPBLOCKNAME"
  else
    echo "Error: parameter RHOCSMODE not set to converged or independent"
    exit 1
  fi

  /usr/bin/mount -t glusterfs $GLUSTERSERVER:/snaps/$SNAPBLOCKNAME/$VOLBLOCKNAME $PARENTMOUNT/$SNAPBLOCKNAME

  ## Now, we have to loop mount each block file inside block-store dir 
  for BLOCKFILE in $PARENTMOUNT/$SNAPBLOCKNAME/block-store/* 
  do
    /usr/bin/mkdir -p $PARENTMOUNT/gluster-block/$SNAPBLOCKNAME/`/bin/basename $BLOCKFILE`
    /usr/bin/mount -o ro,loop,norecovery $BLOCKFILE $PARENTMOUNT/gluster-block/$SNAPBLOCKNAME/`/bin/basename $BLOCKFILE`
    echo "Backing up $BLOCKFILE ..."
    /usr/bin/tar czf $TARGET/`/bin/basename $BLOCKFILE`.tar.gz $PARENTMOUNT/gluster-block/$SNAPBLOCKNAME/`/bin/basename $BLOCKFILE`
    /usr/bin/umount $PARENTMOUNT/gluster-block/$SNAPBLOCKNAME/`/bin/basename $BLOCKFILE`
  done

  /usr/bin/umount $PARENTMOUNT/$SNAPBLOCKNAME

  ## Depending on deployment mode: set of actions to interact with
  ## Gluster commands is different:
  if [ "$RHOCSMODE" = "converged" ]
  then 
    ## Delete Snapshot  
    /usr/bin/ssh $BASTIONHOST "/usr/bin/oc rsh $POD /usr/sbin/gluster snapshot delete $SNAPBLOCKNAME"<<EOF
y
EOF
  fi
  if [ "$RHOCSMODE" = "independent" ]
  then
    ## Delete Snapshot
    /usr/bin/ssh $GLUSTERSERVER "/usr/sbin/gluster snapshot delete $SNAPBLOCKNAME"<<EOF
y
EOF
  fi
  echo "Dismounting and deleting $SNAPBLOCKNAME ..."
done


## Provide Extra information in a file to correlate PVC of gluster-block
## and IQN where directory string of gluster-block PV is stored. 
## Example of output provided: 
## Claim: openshift-logging/logging-es-0
##  IQN: iqn.2016-12.org.gluster-block:1d141850-ff5f-407f-994b-01de011b44dc
## The latest string is the gluster-block directory mounted with contents
## related to the Claim, in this case elastic search files for logging-0 will
## be inside directory 1d1418...
/usr/bin/ssh $BASTIONHOST "/usr/bin/oc login $OCADDRESS -u $OCUSER -p $OCPASS"
echo "Providing info about OCP PVCs with gluster-block IQN info to know contents of directories backed up..."
/usr/bin/ssh $BASTIONHOST "/usr/bin/oc describe pv" | /usr/bin/grep 'Claim\|IQN' | /usr/bin/tr -s " " > $TARGET/info-gluster-block-pvcs-`date +%Y%m%d-%H%M`.txt


## Backing up Heketi DB
echo "Backing up Heketi DB..."
/usr/bin/heketi-cli db dump --server $HEKETI_CLI_SERVER --user $USERHEKETI --secret $SECRETHEKETI > $TARGET/heketidb-`date +%Y%m%d-%H%M`.json

exit 0
