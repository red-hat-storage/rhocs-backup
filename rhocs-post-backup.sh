#!/bin/bash
##
## Script to execute pre-backup tasks for protecting externally 
## existing persistent volumes in OpenShift from Gluster/RHOCS
##

## Environment variables .ini file should be provided as argument
if [ -f $1 ]
then
  source $1
else
  echo "You have to provide a ini file with environment variables as a parameter"
  echo "Example: `basename $0 myvars.ini`"
  exit 1
fi

## Temporary file to put the list of Gluster Snapshots to dismount and delete
SNAPLIST=$SNAPDIR/snaplist-`date +%Y%m%d-%H:%M`.txt 

## Provides Logging of this script in the dir specified below:
LOG="${LOGDIR}/`basename $0`-`date +%Y%m%d-%H:%M`.log"
exec &>> $LOG

BASTIONHOST=localhost

## Source and destination of backups without date
PARENTMOUNT=$PARENTDIR  ## Parent directory for all volumes mounting without date

## Get list of Persistent Volumes Snapshots mounted in this server, 
## store them in file $SNAPLIST 
/usr/bin/df | /usr/bin/grep $GLUSTERSERVER | /usr/bin/grep snaps | /usr/bin/tr -s " " | /usr/bin/cut -d" " -f6 > $SNAPLIST
## If converged mode, get name of gluster pod
if [ "$RHOCSMODE" = "converged" ]
then
  ## Get inside OCP cluster to get access of Gluster pod
  /usr/bin/ssh $BASTIONHOST "/usr/bin/oc login $OCADDRESS -u $OCUSER -p $OCPASS"
  POD=`/usr/bin/ssh $BASTIONHOST "/usr/bin/oc get pods --all-namespaces -o wide" | /usr/bin/grep glusterfs | /usr/bin/grep $GLUSTERSERVER | /usr/bin/tr -s " " | /usr/bin/cut -f2 -d" "`
  echo $POD
  /usr/bin/ssh $BASTIONHOST "/usr/bin/oc project $OCPROJECT"
fi

## For each volume in $SNAPLIST dismount and delete snap 
for VOLNAME in `/usr/bin/cat $SNAPLIST`
do
  ## Get specific name for snapshot from mounted list 
  SNAPNAME=`/usr/bin/echo $VOLNAME | /usr/bin/cut -d"/" -f5`
  /usr/bin/umount $VOLNAME 
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

exit 0
