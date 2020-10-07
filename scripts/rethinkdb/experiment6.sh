#!/bin/bash

set -ex

targetip=$1
targetpid=$2

ssh -i ~/.ssh/id_rsa "$targetip" "sudo sh -c 'sudo mkdir /sys/fs/cgroup/memory/db'"
ssh -i ~/.ssh/id_rsa "$targetip" "sudo sh -c 'sudo echo 2250000 > /sys/fs/cgroup/memory/db/memory.limit_in_bytes'"   # 2.25MB
ssh -i ~/.ssh/id_rsa "$targetip" "sudo sh -c 'sudo echo $targetpid > /sys/fs/cgroup/memory/db/cgroup.procs'"
sleep 5
