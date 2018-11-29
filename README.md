# rhocs-backup

# Script to be used with Backup and Restore 3rd part product

The two scripts, rhocs-pre-backup.sh and rhocs-post-backup.sh are meant to be used in conjunction with a product such as Commvault Complete Backup and Restore. The rhocs-pre-backup.sh script will find gluster file volume, create a gluster snapshot volume, and then mount the volume on a bastion host that has the Commvault agent installed. After the Commvault backup of the mounted snapshot volume the rhocs-post-backup.sh script will unmount the volumes and delete the gluster snapshots.
