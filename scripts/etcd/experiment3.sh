#!/bin/bash

set -ex

secondaryip=$1
username=$2
secondarypid=$3

ssh -i ~/.ssh/id_rsa "$username@$secondaryip" "sudo sh -c 'sudo mkdir /sys/fs/cgroup/blkio/db'"
ssh -i ~/.ssh/id_rsa "$username@$secondaryip" "sudo sh -c 'sync; echo 3 > /proc/sys/vm/drop_caches'"
lsblkcmd="8:32 524288"
ssh -i ~/.ssh/id_rsa "$username@$secondaryip" "sudo sh -c 'sudo echo $lsblkcmd > /sys/fs/cgroup/blkio/db/blkio.throttle.read_bps_device'"                 
ssh -i ~/.ssh/id_rsa "$username@$secondaryip" "sudo sh -c 'sudo echo $lsblkcmd > /sys/fs/cgroup/blkio/db/blkio.throttle.write_bps_device'"                                                                                                                         
ssh -i ~/.ssh/id_rsa "$username@$secondaryip" "sudo sh -c 'sudo echo $secondarypid > /sys/fs/cgroup/blkio/db/cgroup.procs'"
