#!/usr/bin/env bash
export PYTHONUNBUFFERED=1
export ANSIBLE_FORCE_COLOR=1

############################################
# Create Partition table for lvm
############################################
if [ -f /etc/provision_env_disk_added_date ]
then
   echo "Disk partitioning already done"
else

sudo fdisk -u /dev/sdb <<EOF
n
p
1


t
8e

p
w
EOF
date > /etc/provision_env_disk_added_date
fi
