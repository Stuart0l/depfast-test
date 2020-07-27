#!/usr/local/bin/bash

date=$(date +"%Y%m%d%s")
# exec > "$date"_setupserver.log
# exec 2>&1

set -ex

if [ "$#" -ne 7 ]; then
  echo "Wrong number of args"
  echo "1st arg - number of servers to create"
  echo "2nd arg - server prefix name(-1,-2,-3 added as suffix to this name)"
  echo "3rd arg - number of iterations"
  echo "4th arg - workload name"
  echo "5th arg - seconds to run ycsb run"
  echo "6th arg - file system to use(disk,memory)"
  echo "7th arg - ycsb run threads(for saturation exp)"
  exit 1
fi

noOfServers=$1
namePrefix=$2
iterations=$3
workload=$4
ycsbruntime=$5
filesystem=$6
threadsycsb=$7

username="riteshsinha"
resource="DepFast"
serverRegex="cockroachdb$namePrefix-[1-$noOfServers]"
declare -A serverNameIPMap

# Create the VM on Azure
function az_vm_create {
  # Create client VM
  az vm create --name cockroachdb"$namePrefix"-client --resource-group DepFast --subscription 'Microsoft Azure Sponsorship 2' --zone 1 --image debian --os-disk-size-gb 500 --storage-sku Premium_LRS --data-disk-sizes-gb 500 --size Standard_D4s_v3 --admin-username riteshsinha --ssh-key-values ~/.ssh/id_rsa.pub --accelerated-networking true

  # Setup Client IP and name
  clientConfig=$(az vm list-ip-addresses --name cockroachdb"$namePrefix"-client --query '[0].{name:virtualMachine.name, privateip:virtualMachine.network.privateIpAddresses[0], publicip:virtualMachine.network.publicIpAddresses[0].ipAddress}' -o json)
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
    az vm create --name cockroachdb"$namePrefix"-"$i" --resource-group DepFast --subscription 'Microsoft Azure Sponsorship 2' --zone 1 --image debian --os-disk-size-gb 500 --storage-sku Premium_LRS --data-disk-sizes-gb 500 --size Standard_D4s_v3 --admin-username riteshsinha --ssh-key-values ~/.ssh/id_rsa.pub ./client_rsa.pub --accelerated-networking true
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
    ssh -i ~/.ssh/id_rsa ${serverNameIPMap[$key]} "sudo sh -c 'wget -qO- https://binaries.cockroachdb.com/cockroach-v19.2.4.linux-amd64.tgz | tar  xvz ; sudo cp -i cockroach-v19.2.4.linux-amd64/cockroach /usr/local/bin/'"
    scp deadloop "${serverNameIPMap[$key]}":~/
	# Sync clocks - https://www.cockroachlabs.com/docs/stable/deploy-cockroachdb-on-microsoft-azure-insecure.html
	ssh -i ~/.ssh/id_rsa ${serverNameIPMap[$key]} "sudo sh -c 'curl -O https://raw.githubusercontent.com/torvalds/linux/master/tools/hv/lsvmbus'"
	devID=$(ssh -i ~/.ssh/id_rsa ${serverNameIPMap[$key]} "python lsvmbus -vv | grep -w \"Time Synchronization\" -A 3 | grep Device_ID | grep -o '{.*}' | tr -d "{}"")
	ssh -i ~/.ssh/id_rsa ${serverNameIPMap[$key]} "sudo sh -c 'echo "$devID" | sudo tee /sys/bus/vmbus/drivers/hv_util/unbind'"
	ssh -i ~/.ssh/id_rsa ${serverNameIPMap[$key]} "sudo sh -c 'sudo apt-get install ntp ntpstat --assume-yes ; sudo service ntp stop ; sudo ntpd -b time.google.com'"
	ssh -i ~/.ssh/id_rsa ${serverNameIPMap[$key]} "sudo sh -c 'echo -e \"server time1.google.com iburst\nserver time2.google.com iburst\nserver time3.google.com iburst\nserver time4.google.com iburst\" >> /etc/ntp.conf'"
	ssh -i ~/.ssh/id_rsa ${serverNameIPMap[$key]} "sudo sh -c 'sudo service ntp start ; ntpstat ; true'"
  done
}

function run_ssd_experiment {
	ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa $clientPublicIP "(cd ~/ycsb-0.17.0/ ; ./start_experiment.sh $iterations workloads/$workload $ycsbruntime 1 azure noslowfollower disk swapoff 3 $serverRegex $threadsycsb)"

	ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa $clientPublicIP "(cd ~/ycsb-0.17.0/ ; ./start_experiment.sh $iterations workloads/$workload $ycsbruntime 1 azure follower disk swapoff 3 $serverRegex $threadsycsb)"
	ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa $clientPublicIP "(cd ~/ycsb-0.17.0/ ; ./start_experiment.sh $iterations workloads/$workload $ycsbruntime 2 azure follower disk swapoff 3 $serverRegex $threadsycsb)"
	ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa $clientPublicIP "(cd ~/ycsb-0.17.0/ ; ./start_experiment.sh $iterations workloads/$workload $ycsbruntime 3 azure follower disk swapoff 3 $serverRegex $threadsycsb)"
	ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa $clientPublicIP "(cd ~/ycsb-0.17.0/ ; ./start_experiment.sh $iterations workloads/$workload $ycsbruntime 4 azure follower disk swapoff 3 $serverRegex $threadsycsb)"
	ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa $clientPublicIP "(cd ~/ycsb-0.17.0/ ; ./start_experiment.sh $iterations workloads/$workload $ycsbruntime 5 azure follower disk swapoff 3 $serverRegex $threadsycsb)"

	ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa $clientPublicIP "(cd ~/ycsb-0.17.0/ ; ./start_experiment.sh $iterations workloads/$workload $ycsbruntime 1 azure noslowminthroughput disk swapoff 3 $serverRegex $threadsycsb)"

	ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa $clientPublicIP "(cd ~/ycsb-0.17.0/ ; ./start_experiment.sh $iterations workloads/$workload $ycsbruntime 1 azure minthroughput disk swapoff 3 $serverRegex $threadsycsb)"
	ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa $clientPublicIP "(cd ~/ycsb-0.17.0/ ; ./start_experiment.sh $iterations workloads/$workload $ycsbruntime 2 azure minthroughput disk swapoff 3 $serverRegex $threadsycsb)"
	ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa $clientPublicIP "(cd ~/ycsb-0.17.0/ ; ./start_experiment.sh $iterations workloads/$workload $ycsbruntime 3 azure minthroughput disk swapoff 3 $serverRegex $threadsycsb)"
	ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa $clientPublicIP "(cd ~/ycsb-0.17.0/ ; ./start_experiment.sh $iterations workloads/$workload $ycsbruntime 4 azure minthroughput disk swapoff 3 $serverRegex $threadsycsb)"
	ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa $clientPublicIP "(cd ~/ycsb-0.17.0/ ; ./start_experiment.sh $iterations workloads/$workload $ycsbruntime 5 azure minthroughput disk swapoff 3 $serverRegex $threadsycsb)"

	ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa $clientPublicIP "(cd ~/ycsb-0.17.0/ ; ./start_experiment.sh $iterations workloads/$workload $ycsbruntime 1 azure noslowmaxthroughput disk swapoff 3 $serverRegex $threadsycsb)"

	ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa $clientPublicIP "(cd ~/ycsb-0.17.0/ ; ./start_experiment.sh $iterations workloads/$workload $ycsbruntime 1 azure maxthroughput disk swapoff 3 $serverRegex $threadsycsb)"
	ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa $clientPublicIP "(cd ~/ycsb-0.17.0/ ; ./start_experiment.sh $iterations workloads/$workload $ycsbruntime 2 azure maxthroughput disk swapoff 3 $serverRegex $threadsycsb)"
	ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa $clientPublicIP "(cd ~/ycsb-0.17.0/ ; ./start_experiment.sh $iterations workloads/$workload $ycsbruntime 3 azure maxthroughput disk swapoff 3 $serverRegex $threadsycsb)"
	ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa $clientPublicIP "(cd ~/ycsb-0.17.0/ ; ./start_experiment.sh $iterations workloads/$workload $ycsbruntime 4 azure maxthroughput disk swapoff 3 $serverRegex $threadsycsb)"
	ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa $clientPublicIP "(cd ~/ycsb-0.17.0/ ; ./start_experiment.sh $iterations workloads/$workload $ycsbruntime 5 azure maxthroughput disk swapoff 3 $serverRegex $threadsycsb)"
}

function run_memory_experiment {
	ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa $clientPublicIP "(cd ~/ycsb-0.17.0/ ; ./start_experiment.sh $iterations workloads/$workload $ycsbruntime 1 azure follower memory swapoff 3 $serverRegex $threadsycsb)"
}

function setup_client {
ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa $clientPublicIP << EOF_1
	sudo apt install git default-jre --assume-yes
	sudo apt install maven --assume-yes
	curl -O --location https://github.com/brianfrankcooper/YCSB/releases/download/0.17.0/ycsb-0.17.0.tar.gz ; tar xfvz ycsb-0.17.0.tar.gz
	(cd ~/ycsb-0.17.0/jdbc-binding/lib/; wget https://jdbc.postgresql.org/download/postgresql-42.2.10.jar)
	curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
	sudo apt install jq --assume-yes
EOF_1
    # SCP the experiment files to the client. This should run from the script/cockroachdb path
	scp -r ./* $clientPublicIP:~/ycsb-0.17.0/

    ssh -i ~/.ssh/id_rsa $clientPublicIP "sudo sh -c 'wget -qO- https://binaries.cockroachdb.com/cockroach-v19.2.4.linux-amd64.tgz | tar  xvz ; sudo cp -i cockroach-v19.2.4.linux-amd64/cockroach /usr/local/bin/'"
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
	az vm deallocate --name "$clientName" --resource-group "$resource"
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
