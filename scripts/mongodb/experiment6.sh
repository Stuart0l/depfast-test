#!/bin/bash

set -ex

secondaryip=$1
secondarypid=$2

ssh -i ~/.ssh/id_rsa tidb@"$secondaryip" "sudo sh -c 'sudo mkdir /sys/fs/cgroup/memory/db'"
#ssh -i ~/.ssh/id_rsa tidb@"$secondaryip" "sudo sh -c 'sudo echo 1 > /sys/fs/cgroup/memory/db/memory.memsw.oom_control'"  # disable OOM killer
#ssh -i ~/.ssh/id_rsa tidb@"$secondaryip" "sudo sh -c 'sudo echo 10485760 > /sys/fs/cgroup/memory/db/memory.memsw.limit_in_bytes'"   # 10MB
# ssh -i ~/.ssh/id_rsa tidb@"$secondaryip" "sudo sh -c 'sudo echo 1 > /sys/fs/cgroup/memory/db/memory.oom_control'"  # disable OOM killer
ssh -i ~/.ssh/id_rsa tidb@"$secondaryip" "sudo sh -c 'sudo echo 51042880 > /sys/fs/cgroup/memory/db/memory.limit_in_bytes'"   # 5MB
ssh -i ~/.ssh/id_rsa tidb@"$secondaryip" "sudo sh -c 'sudo echo $secondarypid > /sys/fs/cgroup/memory/db/cgroup.procs'"
sleep 60

