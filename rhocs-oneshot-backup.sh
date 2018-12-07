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

## Temporary file to put the list of Gluster volumes to backup
VOLLIST=/root/vollist-`date +%Y%m%d-%H:%M`.txt 

## Provides Logging of this script in the dir specified below:
LOG="${LOGDIR}/`basename $0`-`date +%Y%m%d-%H:%M`.log"
exec &>> $LOG

BASTIONHOST=localhost

## Source and destination of backups
PARENTMOUNT=$PARENTDIR/backup-`date +%Y%m%d-%H%M`  ## Parent directory for all volumes mounting
/usr/bin/mkdir $PARENTMOUNT
TARGET=$DESTINATION/backup-`date +%Y%m%d-%H%M` ## Daily/Hourly destination of backups

## Get list of Persistent Volumes in Gluster with Heketi till now and 
## store them in file $VOLLIST , exclude gluster-block and heketidb
/usr/bin/heketi-cli volume list --server $HEKETI_CLI_SERVER --user $USERHEKETI --secret $SECRETHEKETI | /usr/bin/grep -v block | /usr/bin/grep -v heketidbstorage | /usr/bin/cut -d":" -f4 > $VOLLIST

## If converged mode, get name of gluster pod
if [ "$RHOCSMODE" = "converged" ]
then 
  ## Get inside OCP cluster to get access of Gluster pod
  /usr/bin/ssh $BASTIONHOST "/usr/bin/oc login $OCADDRESS -u $OCUSER -p $OCPASS"
  POD=`/usr/bin/ssh $BASTIONHOST "/usr/bin/oc get pods --all-namespaces -o wide" | /usr/bin/grep glusterfs | /usr/bin/grep $GLUSTERSERVER | /usr/bin/tr -s " " | /usr/bin/cut -f2 -d" "`
  echo $POD
  /usr/bin/ssh $BASTIONHOST "/usr/bin/oc project $OCPROJECT"
fi

## For each volume in $VOLLIST create mount directory, mount it,
## and copy to destination (and umount)
/usr/bin/mkdir $TARGET
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

## Backing up Heketi DB
echo "Backing up Heketi DB..."
/usr/bin/heketi-cli db dump --server $HEKETI_CLI_SERVER --user $USERHEKETI --secret $SECRETHEKETI > $TARGET/heketidb-`date +%Y%m%d-%H%M`.json

exit 0
