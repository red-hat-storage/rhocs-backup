# rhocs-backup

## Scripts to be used with Commerical Backup and Restore products

This repository contains unsupported code that can be used in conjunction with Commerical Backup and Restore products. The two scripts, rhocs-pre-backup.sh and rhocs-post-backup.sh, have been tested with Commvault Complete Backup and Restore. The rhocs-pre-backup.sh script will find gluster file volumes, create a gluster snapshot for each volume, and then mount the volume on a bastion host that has the backup agent installed. After the backup of the mounted snapshot volume by backup server, the rhocs-post-backup.sh script will unmount the volumes and delete the gluster snapshots.

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



