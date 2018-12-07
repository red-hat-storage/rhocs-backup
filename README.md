# rhocs-backup

## Scripts to be used with Backup and Restore products

This repository contains unsupported code that can be used in conjunction with Backup and Restore products. The two scripts, rhocs-pre-backup.sh and rhocs-post-backup.sh, have been tested with Commvault Complete Backup and Restore. The rhocs-pre-backup.sh script will find gluster file volumes, create a gluster snapshot for each volume, and then mount the volume on a bastion host that has the backup agent installed. After the backup of the mounted snapshot volume by backup server, the rhocs-post-backup.sh script will unmount the volumes and delete the gluster snapshots.

The two ini files, independent_vars.ini and converged_vars.ini, are used to specify paramaters specific to your deployment. Example for converged_var.ini.
```
## Environment variables for RHOCS Backup: 
## Deployment mode for RHOCS cluster: converged (CNS) or independent (CRS)
export RHOCSMODE="converged"

## Authentication variables for accessing OpenShift cluster or
## Gluster nodes depending on deployment mode
export OCADDRESS="https://master.refarch311.ocpgluster.com:443"
export OCUSER="openshift"
export OCPASS="redhat"
export OCPROJECT="app-storage" ## OpenShift project where gluster cluster lives

## For "independent" mode, it's required to have passwordless SSH
## from this root user to gluster server root
## Any of the Gluster nodes from RHOCS cluster you want to protect
export GLUSTERSERVER=172.16.31.173

## Directory for temporary files to put the list of 
## Gluster volumes /snaps to backup
export VOLDIR=/root
export SNAPDIR=/root

## Destination directory for mounting snapshots of Gluster volumes:
export PARENTDIR=/mnt/source

## Heketi Route and Credentials
export USERHEKETI=admin ## User with admin permissions to dialog with Heketi
export SECRETHEKETI="xzAqO62qTPlacNjk3oIX53n2+Z0Z6R1Gfr0wC+z+sGk=" ## Heketi user key
export HEKETI_CLI_SERVER=http://heketi-storage-app-storage.apps.refarch311.ocpgluster.com ## Route where Heketi pod is listening

## Provides Logging of this script in the dir specified below:
export LOGDIR="/root"
```
## Manual Execution of pre-backup and post-backup Scripts
The scripts can be manually executed in the following manner for RHOCS converged mode:
```
sudo ./rhocs-pre-backup.sh /path to file/converged_vars.ini
```
followed by
```
sudo ./rhocs-post-backup.sh /path to file/converged_vars.ini
```
The scripts can be manually executed in the following manner for RHOCS independent mode:
```
sudo ./rhocs-pre-backup.sh /path to file/independent_vars.ini
```
followed by
```
sudo ./rhocs-post-backup.sh /path to file/independent_vars.ini
```
For each execution of the pre-backup or post-backup script a log file will be generated and placed in the directory specified in the ini file (default is /root). 
## Script to be used to backup RH OCS in a standalone way (no backup app integration) 
This repository also contains an individual script, called rhocs-oneshot-backup.sh, that is meant to be used to back up externally gluster-file volumes from a RHOCS cluster, without integrating this solution with a corporate backup application, as rhocs-pre-backup.sh and rhocs-post-backup.sh intend to do.
This script backs up the contents of all existing Persistent Volumes (PVs) based on glusterfs-file from a specific RHOCS cluster to a $DESTINATION folder. RHOCS cluster can be independent mode (formerly CRS) or converged mode (formerly CNS). And all environment variables required are taken from same files independent_vars.ini and converged_vars.ini than rhocs-pre-backup.sh and rhocs-post-backup.sh scripts. A DESTINATION variable with a reachable folder from execution host with enough capacity to hold the backup of all gluster volumes is required in these ini files. 
The actions taken by the script are the sequential execution of tasks done in rhocs-pre-backup.sh, plus a tar czf to $DESTINATION folder, and tasks done in rhocs-post-backup.sh. The tar command is replacing the backup process that is normally done by corporate backup applications (without cataloguing backed up contents).
The script can be manually executed in the same manner than previous scripts, with root permissions to mount and unmount gluster snapshots:
```
sudo ./rhocs-oneshot-backup.sh </path to file/converged_vars.ini>
```
in the case of Converged RHOCS or the following in the case of Independent RHOCS:
```
sudo ./rhocs-oneshot-backup.sh </path to file/independent_vars.ini>
```


