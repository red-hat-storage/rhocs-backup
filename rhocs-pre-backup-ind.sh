#!/bin/bash
##
## Script to execute pre-backup tasks for protecting externally 
## existing persistent volumes in OpenShift from Gluster/RHOCS
##

## Environment variables: (you can also put them in a .ini kind of file)
## Deployment mode for RHOCS cluster: converged (CNS) or independent (CRS)
RHOCSMODE="independent" 

## Authentication variables for accessing OpenShift cluster or 
## Gluster nodes depending on deployment mode
OCADDRESS="https://master.refarch311.makestoragegreatagain.com:443"
OCUSER="openshift"
OCPASS="redhat"
OCPROJECT="infra-storage" ## OpenShift project where gluster cluster lives

## For "independent" mode, it's required to have passwordless SSH 
## from this root user to gluster server root
## Any of the Gluster nodes from RHOCS cluster you want to protect
GLUSTERSERVER=172.16.25.67

## Temporary file to put the list of Gluster volumes to backup
VOLLIST=/root/vollist-`date +%Y%m%d-%H:%M`.txt 

## Heketi Route and Credentials
USERHEKETI=admin ## User with admin permissions to dialog with Heketi
SECRETHEKETI="xzAqO62qTPlacNjk3oIX53n2+Z0Z6R1Gfr0wC+z+sGk=" ## Heketi user key
HEKETI_CLI_SERVER=http://heketi-registry-infra-storage.apps.refarch311.makestoragegreatagain.com ## Route where Heketi pod is listening

## Source and destination of backups
PARENTMOUNT=/mnt/source/backup-`date +%Y%m%d-%H%M`  ## Parent directory for all volumes mounting
/usr/bin/mkdir $PARENTMOUNT

## Get list of Persistent Volumes in Gluster with Heketi till now and 
## store them in file $VOLLIST , exclude gluster-block and heketidb
/usr/bin/heketi-cli volume list --server $HEKETI_CLI_SERVER --user $USERHEKETI --secret $SECRETHEKETI | /usr/bin/grep -v block | /usr/bin/grep -v heketidbstorage | /usr/bin/cut -d":" -f4 > $VOLLIST

## If converged mode, get name of gluster pod
if [ "$RHOCSMODE" = "converged" ]
then 
  ## Get inside OCP cluster to get access of Gluster pod
  /usr/bin/oc login $OCADDRESS -u $OCUSER -p $OCPASS 
  POD=`/usr/bin/oc get pods --all-namespaces -o wide | /usr/bin/grep glusterfs | /usr/bin/grep $GLUSTERSERVER | /usr/bin/tr -s " " | /usr/bin/cut -f2 -d" "`
  echo $POD
  /usr/bin/oc project $OCPROJECT
fi

## For each volume in $VOLLIST create mount directory, mount it,
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
    /usr/bin/oc rsh $POD /bin/bash -c "/usr/sbin/gluster snapshot create $SNAPNAME $VOLNAME no-timestamp"
    /usr/bin/oc rsh $POD /bin/bash -c "/usr/sbin/gluster snapshot activate $SNAPNAME"
  fi
  if [ "$RHOCSMODE" = "independent" ]
  then
    ## Create snpashot and activate for VOLNAME 
    /usr/bin/ssh $GLUSTERSERVER "/usr/sbin/gluster snapshot create $SNAPNAME $VOLNAME no-timestamp"
    /usr/bin/ssh $GLUSTERSERVER "/usr/sbin/gluster snapshot activate $SNAPNAME"
  fi
  /usr/bin/mount -t glusterfs $GLUSTERSERVER:/snaps/$SNAPNAME/$VOLNAME $PARENTMOUNT/$SNAPNAME
  echo "The Gluster snapshot $SNAPNAME is ready to be backed up..."
done

## Backing up Heketi DB
echo "Backing up Heketi DB..."
/usr/bin/heketi-cli db dump --server $HEKETI_CLI_SERVER --user $USERHEKETI --secret $SECRETHEKETI > $PARENTMOUNT/heketidb-`date +%Y%m%d-%H%M`.json

exit 0
