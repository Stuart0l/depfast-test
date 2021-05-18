#!/bin/bash

# Arguments
# 1. the VM group - in most cases, this is just 01
# 2. Name of experiment
# 3. Number of threads
# 4. Duration
# 5. Throttling method (0 for No slowness, 1 for CPU slowness, 2 for CPU contention,
#                      3 for Disk slowness, 4 for Disk contention, 5 for Network slowness,
#                      6 for Memory slowness)
# 6. Throttled server (leader, follower)

vmGrp=$1
name=$2
threads=$3
duration=$4
expr=$5
victim=$6

az vm start --ids $(az vm list --query "[].id" -o tsv | grep "andrew-$vmGrp-janus-ssd")

sleep 60
ip_addr=`az vm list-ip-addresses -g DepFast -n andrew-$vmGrp-janus-ssd-server1 --query [0].virtualMachine.network.publicIpAddresses[0].ipAddress -o tsv`
ssh -o StrictHostKeyChecking=no xuhao@$ip_addr './setup-server.sh'

ip_addr=`az vm list-ip-addresses -g DepFast -n andrew-$vmGrp-janus-ssd-server2 --query [0].virtualMachine.network.publicIpAddresses[0].ipAddress -o tsv`
ssh -o StrictHostKeyChecking=no xuhao@$ip_addr './setup-server.sh'

ip_addr=`az vm list-ip-addresses -g DepFast -n andrew-$vmGrp-janus-ssd-server3 --query [0].virtualMachine.network.publicIpAddresses[0].ipAddress -o tsv`
ssh -o StrictHostKeyChecking=no xuhao@$ip_addr './setup-server.sh'

ip_addr=`az vm list-ip-addresses -g DepFast -n andrew-$vmGrp-janus-ssd-client --query [0].virtualMachine.network.publicIpAddresses[0].ipAddress -o tsv`
ssh -o StrictHostKeyChecking=no -o ServerAliveInterval=120 xuhao@$ip_addr << EOF
  if [ -f "depfast/config/concurrent_$threads.yml" ]; then
    echo "concurrent_$threads.yml exists"
  else
    echo -e "\nn_concurrent: $threads\n" > depfast/config/concurrent_$threads.yml
    if [ -f "depfast/config/concurrent_$threads.yml" ]; then
      echo "file successfully created"
    fi
  fi
  nohup ./start-exp-epaxos.sh $name $threads $duration $expr 3 $victim
EOF

az vm deallocate --ids $(az vm list --query "[].id" -o tsv | grep "andrew-$vmGrp-janus-ssd")
