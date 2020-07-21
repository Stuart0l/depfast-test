#!/usr/local/bin/bash

date=$(date +"%Y%m%d%s")
# exec > "$date"_setupserver.log
# exec 2>&1

set -ex

if [ "$#" -ne 6 ]; then
  echo "Wrong number of args"
  echo "1st arg - number of servers to create"
  echo "2nd arg - server prefix name(-1,-2,-3 added as suffix to this name)"
  echo "3rd arg - number of iterations"
  echo "4th arg - workload name"
  echo "5th arg - seconds to run ycsb run"
  echo "6th arg - file system to use(disk,memory)"
  exit 1
fi

noOfServers=$1
namePrefix=$2
iterations=$3
workload=$4
ycsbruntime=$5
filesystem=$6

username="riteshsinha"
serverRegex="rethinkdb$namePrefix-[1-$noOfServers]"
declare -A serverNameIPMap

# Create the VM on Azure
function az_vm_create {
  # Create client VM
  az vm create --name rethinkdb"$namePrefix"-client --resource-group DepFast --subscription 'Microsoft Azure Sponsorship 2' --zone 1 --image debian --os-disk-size-gb 500 --storage-sku Premium_LRS --data-disk-sizes-gb 500 --size Standard_D4s_v3 --admin-username riteshsinha --ssh-key-values ~/.ssh/id_rsa.pub --accelerated-networking true

  # Setup Client IP and name
  clientConfig=$(az vm list-ip-addresses --name rethinkdb"$namePrefix"-client --query '[0].{name:virtualMachine.name, privateip:virtualMachine.network.privateIpAddresses[0], publicip:virtualMachine.network.publicIpAddresses[0].ipAddress}' -o json)
  clientPrivateIP=$(echo $clientConfig | jq .privateip)
  clientPrivateIP=$(sed -e "s/^'//" -e "s/'$//" <<<"$clientPrivateIP")
  clientPrivateIP=$(sed -e 's/^"//' -e 's/"$//' <<<"$clientPrivateIP")
  clientName=$(echo $clientConfig | jq .name)
  clientName=$(sed -e "s/^'//" -e "s/'$//" <<<"$clientName")
  clientName=$(sed -e 's/^"//' -e 's/"$//' <<<"$clientName")
  clientPublicIP=$(echo $clientConfig | jq .publicip)
  clientPublicIP=$(sed -e "s/^'//" -e "s/'$//" <<<"$clientPublicIP")
  clientPublicIP=$(sed -e 's/^"//' -e 's/"$//' <<<"$clientPublicIP")

  # Run ssh-keygen on client VM
  ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa $clientPublicIP 'ssh-keygen -t rsa -f ~/.ssh/id_rsa -q -P "" <<<y 2>&1 >/dev/null '
  # Scp the client id_rsa.pub to local directory
  scp $clientPublicIP:~/.ssh/id_rsa.pub ./client_rsa.pub

  # Create servers with both local ssh key and client VM ssh key
  for (( i=1; i<=noOfServers; i++ ))
  do
    az vm create --name rethinkdb"$namePrefix"-"$i" --resource-group DepFast --subscription 'Microsoft Azure Sponsorship 2' --zone 1 --image debian --os-disk-size-gb 500 --storage-sku Premium_LRS --data-disk-sizes-gb 500 --size Standard_D4s_v3 --admin-username riteshsinha --ssh-key-values ~/.ssh/id_rsa.pub ./client_rsa.pub --accelerated-networking true
  done
}

function write_config {
	rm -f config.json
	az vm list-ip-addresses --ids $(az vm list --query "[].id" --resource-group DepFast -o tsv | grep $serverRegex) --query '[].{name:virtualMachine.name, privateip:virtualMachine.network.privateIpAddresses[0], publicip:virtualMachine.network.publicIpAddresses[0].ipAddress}' -o json > config.json
}

# Set the IPs of the given VM
function find_ip {
  for (( i=0; i<$noOfServers; i++ ))
  do  
    servername=$(cat config.json  | jq .[$i].name)
	servername="${servername%\"}"
	servername="${servername#\"}"
    serverip=$(cat config.json  | jq .[$i].publicip)
	serverip="${serverip%\"}"
	serverip="${serverip#\"}"
    serverNameIPMap[$servername]=$serverip
  done
}

# Setup the servers to install tools and DB
function setup_servers {
  for key in "${!serverNameIPMap[@]}";
  do
    # Run the commands
    ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa ${serverNameIPMap[$key]} "sudo sh -c 'sudo apt install tmux wget git --assume-yes ; sudo apt-get install cgroup-tools --assume-yes ; sudo apt-get install xfsprogs --assume-yes'"
    ssh -i ~/.ssh/id_rsa ${serverNameIPMap[$key]} "sudo sh -c 'wget https://download.rethinkdb.com/repository/debian-buster/pool/r/rethinkdb/rethinkdb_2.4.0~0buster_amd64.deb ; sudo apt install ./rethinkdb_2.4.0~0buster_amd64.deb --assume-yes'"
    scp deadloop "${serverNameIPMap[$key]}":~/
  done
}

function run_ssd_experiment {
ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa $clientPublicIP << EOF_2
	# Run all the experiments one by one
	cd ~/YCSB
	:
	./start_experiment.sh $iterations workloads/$workload $ycsbruntime 1 azure noslow disk swapoff 3 $serverRegex

	./start_experiment.sh $iterations workloads/$workload $ycsbruntime 1 azure follower disk swapoff 3 $serverRegex
	./start_experiment.sh $iterations workloads/$workload $ycsbruntime 2 azure follower disk swapoff 3 $serverRegex
	./start_experiment.sh $iterations workloads/$workload $ycsbruntime 3 azure follower disk swapoff 3 $serverRegex
	./start_experiment.sh $iterations workloads/$workload $ycsbruntime 4 azure follower disk swapoff 3 $serverRegex
	./start_experiment.sh $iterations workloads/$workload $ycsbruntime 5 azure follower disk swapoff 3 $serverRegex

	./start_experiment.sh $iterations workloads/$workload $ycsbruntime 1 azure leader disk swapoff 3 $serverRegex
	./start_experiment.sh $iterations workloads/$workload $ycsbruntime 2 azure leader disk swapoff 3 $serverRegex
	./start_experiment.sh $iterations workloads/$workload $ycsbruntime 3 azure leader disk swapoff 3 $serverRegex
	./start_experiment.sh $iterations workloads/$workload $ycsbruntime 4 azure leader disk swapoff 3 $serverRegex
	./start_experiment.sh $iterations workloads/$workload $ycsbruntime 5 azure leader disk swapoff 3 $serverRegex
EOF_2
}

function run_memory_experiment {
	ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa $clientPublicIP "(cd ~/YCSB/ ; ./start_experiment.sh $iterations workloads/$workload $ycsbruntime 1 azure follower memory swapoff 3 $serverRegex)"
}

function run_memory_experiment2 {
ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa $clientPublicIP << EOF_3
	# Run all the experiments one by one
	cd ~/YCSB
	:
	./start_experiment.sh $iterations workloads/$workload $ycsbruntime 1 azure noslow memory swapoff 3 $serverRegex

	./start_experiment.sh $iterations workloads/$workload $ycsbruntime 1 azure follower memory swapoff 3 $serverRegex
	./start_experiment.sh $iterations workloads/$workload $ycsbruntime 2 azure follower memory swapoff 3 $serverRegex
	./start_experiment.sh $iterations workloads/$workload $ycsbruntime 5 azure follower memory swapoff 3 $serverRegex
	./start_experiment.sh $iterations workloads/$workload $ycsbruntime 6 azure follower memory swapon 3 $serverRegex

	./start_experiment.sh $iterations workloads/$workload $ycsbruntime 1 azure noslow memory swapon 3 $serverRegex

	./start_experiment.sh $iterations workloads/$workload $ycsbruntime 1 azure leader memory swapoff 3 $serverRegex
	./start_experiment.sh $iterations workloads/$workload $ycsbruntime 2 azure leader memory swapoff 3 $serverRegex
	./start_experiment.sh $iterations workloads/$workload $ycsbruntime 5 azure leader memory swapoff 3 $serverRegex
	./start_experiment.sh $iterations workloads/$workload $ycsbruntime 6 azure leader memory swapon 3 $serverRegex
EOF_3
}

function setup_client {
ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa $clientPublicIP << EOF_1
	sudo apt install git default-jre --assume-yes
	sudo apt install maven --assume-yes
	(cd ~ ; git clone https://github.com/rethinkdb/YCSB.git)
	(cd ~/YCSB/ ; sudo apt-get install python3-venv --assume-yes ; python3 -m venv ./venv ; source venv/bin/activate ; pip install rethinkdb )
	curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
	sudo apt install jq --assume-yes
EOF_1
    # SCP the experiment files to the client. This should run from the script/rethinkdb path
	scp -r ./* $clientPublicIP:~/YCSB/
	ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa $clientPublicIP "(cd ~/YCSB/ ; git apply ycsb_diff)"
	ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa $clientPublicIP "(cd ~/YCSB/ ; mvn -pl com.yahoo.ycsb:rethinkdb-binding -am clean package -DskipTests)"

	# Create a service principal for azure login from the client VM
	rm -f serviceprincipal.json
	az ad sp create-for-rbac --name $namePrefix > serviceprincipal.json
	appID=$(cat serviceprincipal.json | jq .appId)
    appID=$(sed -e "s/^'//" -e "s/'$//" <<<"$appID")
	password=$(cat serviceprincipal.json | jq .password)
    password=$(sed -e "s/^'//" -e "s/'$//" <<<"$password")
	tenantID=$(cat serviceprincipal.json | jq .tenant)
    tenantID=$(sed -e "s/^'//" -e "s/'$//" <<<"$tenantID")
	sleep 30
	ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa $clientPublicIP "az login --service-principal --username $appID --password $password --tenant $tenantID"
}

function deallocate_vms {
	ns=$(az vm list --query "[].id" --resource-group DepFast -o tsv | grep $serverRegex | wc -l)
	if [[ $ns -le 5 ]]
	then
		az vm deallocate --ids $(
			az vm list --query "[].id" --resource-group DepFast -o tsv | grep $serverRegex
		)
	else
		echo "Server regex malformed, performing linear stop"
		# Switching back to linear stop
		for key in "${!serverNameIPMap[@]}";
		do
			az vm deallocate --name "$key" --resource-group "$resource"
		done
	fi
}

function main {
  az_vm_create

  write_config

  find_ip

  setup_servers

  setup_client

  if [ "$filesystem" == "disk" ]; then
	run_ssd_experiment
  elif [ "$filesystem" == "memory" ]; then
	run_memory_experiment
  else
		echo "This option in filesystem is not supported.Exiting."
		exit 1
  fi

  deallocate_vms
}

main