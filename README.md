# rhocs-backup

## Scripts to be used with Commerical Backup and Restore products

The two scripts, rhocs-pre-backup.sh and rhocs-post-backup.sh, are meant to be used in conjunction with a product such as Commvault Complete Backup and Restore. The rhocs-pre-backup.sh script will find gluster file volumes, create a gluster snapshot for each volume, and then mount the volume on a bastion host that has the backup agent installed. After the backup of the mounted snapshot volume by backup server the rhocs-post-backup.sh script will unmount the volumes and delete the gluster snapshots.
## Using pre-backup and post-backup script with Commvault
