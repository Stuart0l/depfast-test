#!/bin/bash

# Arguments
# 1. the VM group - in most cases, this is just 01
# 2. Name of experiment

az vm start --ids $(az vm list --query "[].id" -o tsv | grep "andrew-$1-janus-ssd")

sleep 60
ip_addr=`az vm list-ip-addresses -g DepFast -n andrew-$1-janus-ssd-server1 --query [0].virtualMachine.network.publicIpAddresses[0].ipAddress -o tsv`
ssh -o StrictHostKeyChecking=no xuhao@$ip_addr './setup-server.sh'

ip_addr=`az vm list-ip-addresses -g DepFast -n andrew-$1-janus-ssd-server2 --query [0].virtualMachine.network.publicIpAddresses[0].ipAddress -o tsv`
ssh -o StrictHostKeyChecking=no xuhao@$ip_addr './setup-server.sh'

ip_addr=`az vm list-ip-addresses -g DepFast -n andrew-$1-janus-ssd-server3 --query [0].virtualMachine.network.publicIpAddresses[0].ipAddress -o tsv`
ssh -o StrictHostKeyChecking=no xuhao@$ip_addr './setup-server.sh'

ip_addr=`az vm list-ip-addresses -g DepFast -n andrew-$1-janus-ssd-client --query [0].virtualMachine.network.publicIpAddresses[0].ipAddress -o tsv`
ssh -o StrictHostKeyChecking=no -o ServerAliveInterval=120 xuhao@$ip_addr << EOF
  if [ -f "depfast/config/concurrent_$3.yml" ]; then
    echo "concurrent_$3.yml exists"
  else
    echo -e "\nn_concurrent: $3\n" > depfast/config/concurrent_$3.yml
    if [ -f "depfast/config/concurrent_$3.yml" ]; then
      echo "file successfully created"
    fi
  fi
  nohup ./start-exp-epaxos.sh $2 $3 $4 $5 3 $6
EOF

az vm deallocate --ids $(az vm list --query "[].id" -o tsv | grep "andrew-$1-janus-ssd")
