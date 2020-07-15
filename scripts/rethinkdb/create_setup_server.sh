#!/bin/bash

date=$(date +"%Y%m%d%s")
exec > "$date"_setupserver.log
exec 2>&1

set -ex

if [ "$#" -ne 2 ]; then
  echo "Wrong number of args"
  echo "1st arg - number of servers to create"
  echo "2nd arg - server prefix name(-1,-2,-3 added as suffix to this name)"
fi

noOfServers=$1
namePrefix=$2
# serverIP array to store the servers IP address
declare -a serverIP

# Create the VM on Azure
function az_vm_create {
  for (( i=1; i<=noOfServers; i++ ))
  do
    az vm create --name "$namePrefix"-"$i" --resource-group DepFast --subscription 'Microsoft Azure Sponsorship 2' --zone 1 --image debian --os-disk-size-gb 500 --storage-sku Premium_LRS --data-disk-sizes-gb 500 --size Standard_D4s_v3 --admin-username riteshsinha --ssh-key-values ~/.ssh/id_rsa.pub --accelerated-networking true
    #az vm deallocate --resource-group DepFast --name "$namePrefix"-"$i"
  done
}

# Set the IPs of the given VM
function find_ip {
  for (( i=1; i<=noOfServers; i++ ))
  do
    serverIP["$i"]=$(az vm list-ip-addresses --name "$namePrefix"-"$i" --resource-group 'DepFast' -o table | awk '{print $3}' | grep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}')
  done
}

# Setup the servers to install tools and DB
function setup_servers {
  for ip in "${serverIP[@]}";
  do
    # Run the commands
    ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa "$ip" "sudo sh -c 'sudo apt install tmux wget git --assume-yes ; sudo apt-get install cgroup-tools --assume-yes ; sudo apt-get install xfsprogs --assume-yes'"
    ssh -i ~/.ssh/id_rsa "$ip" "sudo sh -c 'wget https://download.rethinkdb.com/repository/debian-buster/pool/r/rethinkdb/rethinkdb_2.4.0~0buster_amd64.deb ; sudo apt install ./rethinkdb_2.4.0~0buster_amd64.deb --assume-yes'"
    scp deadloop "$ip":~/
  done
}

function setup_client {
  sudo apt install git default-jre --assume-yes
  sudo apt install maven --assume-yes
  (cd ~ ; git clone https://github.com/rethinkdb/YCSB.git)
  (cd ~/YCSB/ ; sudo apt-get install python3-venv --assume-yes ; python3 -m venv ./venv ; source venv/bin/activate ; pip install rethinkdb )
  cdir=$(echo $PWD)
  (cd ~/YCSB/ ; git apply "$cdir"/ycsb_diff)
  (cd ~/YCSB/ ; mvn -pl com.yahoo.ycsb:rethinkdb-binding -am clean package -DskipTests)
  # Copy workloada_more file
  cp workloads/workloada_more ~/YCSB/workloads/     
}

function main {
  az_vm_create

  find_ip

  setup_servers

  setup_client
}

main
