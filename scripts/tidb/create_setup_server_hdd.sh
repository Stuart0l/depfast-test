#!/bin/bash

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

# username="tidb"
resource="DepFast3"
serverRegex="tidb$namePrefix_"
declare -A serverNameIPMap

function setup_localvm {
  clientPublicIP="192.168.1.19"
  pdPublicIP="192.168.1.17"
  serverNameIPMap["s1"]="192.168.1.15"
  serverNameIPMap["s2"]="192.168.1.16"
  serverNameIPMap["s3"]="192.168.1.18"
  serverNameIPMap["pd"]=$pdPublicIP
}

# Create the VM on Azure
function az_vm_create {
  rm ~/.ssh/known_hosts

  # Create client VM
  az vm create --name tidb"$namePrefix"_client --resource-group DepFast3 --subscription 'Last Chance' --zone 1 --image debian --os-disk-size-gb 64 --storage-sku Standard_LRS  --size Standard_D4s_v3 --admin-username tidb --ssh-key-values ~/.ssh/id_rsa.pub --accelerated-networking true
  # Setup Client IP and name
  clientConfig=$(az vm list-ip-addresses --name tidb"$namePrefix"_client --query '[0].{name:virtualMachine.name, privateip:virtualMachine.network.privateIpAddresses[0], publicip:virtualMachine.network.publicIpAddresses[0].ipAddress}' -o json)
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
  ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa tidb@$clientPublicIP 'ssh-keygen -t rsa -f ~/.ssh/id_rsa -q -P "" <<<y 2>&1 >/dev/null '
  # Scp the client id_rsa.pub to local directory
  scp tidb@$clientPublicIP:~/.ssh/id_rsa.pub ./client_rsa.pub

  # Create pd VM
  az vm create --name tidb"$namePrefix"_pd --resource-group DepFast3 --subscription 'Last Chance' --zone 1 --image debian --os-disk-size-gb 64 --storage-sku Premium_LRS --data-disk-sizes-gb 64 --size Standard_D4s_v3 --admin-username tidb --ssh-key-values ~/.ssh/id_rsa.pub ./client_rsa.pub --accelerated-networking true
  # Setup pd IP and name
  pdConfig=$(az vm list-ip-addresses --name tidb"$namePrefix"_pd --query '[0].{name:virtualMachine.name, privateip:virtualMachine.network.privateIpAddresses[0], publicip:virtualMachine.network.publicIpAddresses[0].ipAddress}' -o json)
  pdPrivateIP=$(echo $pdConfig | jq .privateip)
  pdPrivateIP=$(sed -e "s/^'//" -e "s/'$//" <<<"$pdPrivateIP")
  pdPrivateIP=$(sed -e 's/^"//' -e 's/"$//' <<<"$pdPrivateIP")
  pdName=$(echo $pdConfig | jq .name)
  pdName=$(sed -e "s/^'//" -e "s/'$//" <<<"$pdName")
  pdName=$(sed -e 's/^"//' -e 's/"$//' <<<"$pdName")
  pdPublicIP=$(echo $pdConfig | jq .publicip)
  pdPublicIP=$(sed -e "s/^'//" -e "s/'$//" <<<"$pdPublicIP")
  pdPublicIP=$(sed -e 's/^"//' -e 's/"$//' <<<"$pdPublicIP")

  # Run ssh-keygen on pd VM
  ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa tidb@$pdPublicIP 'ssh-keygen -t rsa -f ~/.ssh/id_rsa -q -P "" <<<y 2>&1 >/dev/null '
  # Scp the pd id_rsa.pub to local directory
  scp tidb@$pdPublicIP:~/.ssh/id_rsa.pub ./pd_rsa.pub

  # Create servers with both local ssh key and client VM ssh key
  for (( i=1; i<=noOfServers; i++ ))
  do
    az vm create --name tidb"$namePrefix"_tikv"$i" --resource-group DepFast3 --subscription 'Last Chance' --zone 1 --image debian --os-disk-size-gb 64 --storage-sku Premium_LRS --data-disk-sizes-gb 64 --size Standard_D4s_v3 --admin-username tidb --ssh-key-values ~/.ssh/id_rsa.pub ./client_rsa.pub ./pd_rsa.pub --accelerated-networking true
  done

}

function write_config {
	rm -f config.json
	az vm list-ip-addresses --ids $(az vm list --query "[].id" --resource-group DepFast3 -o tsv | grep $serverRegex) --query '[].{name:virtualMachine.name, privateip:virtualMachine.network.privateIpAddresses[0], publicip:virtualMachine.network.publicIpAddresses[0].ipAddress}' -o json > config.json
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
  serverNameIPMap["pd"]=$pdPublicIP
}

# Setup the servers to install tools and DB
function setup_servers {
  for key in "${!serverNameIPMap[@]}";
  do
    # Run the commands
    ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa tidb@${serverNameIPMap[$key]} "sudo sh -c 'sudo apt install tmux wget git --assume-yes ; sudo apt-get install cgroup-tools --assume-yes ; sudo apt-get install libc6 xfsprogs --assume-yes'"
    scp deadloop tidb@"${serverNameIPMap[$key]}":~/
    ssh -i ~/.ssh/id_rsa tidb@${serverNameIPMap[$key]} "curl --proto '=https' --tlsv1.2 -sSf https://tiup-mirrors.pingcap.com/install.sh | sh"
	  ssh -i ~/.ssh/id_rsa tidb@${serverNameIPMap[$key]} "sudo sh -c 'sudo echo export PATH=\$PATH:/home/tidb/.tiup/bin >> /etc/profile'"
    ssh -i ~/.ssh/id_rsa tidb@${serverNameIPMap[$key]} "source /etc/profile"
    ssh -i ~/.ssh/id_rsa tidb@${serverNameIPMap[$key]} "./.tiup/bin/tiup cluster"
    ssh -i ~/.ssh/id_rsa tidb@${serverNameIPMap[$key]} "./.tiup/bin/tiup --binary cluster"
	  # TODO: specially for azure
#  	ssh -i ~/.ssh/id_rsa tidb@${serverNameIPMap[$key]} "sudo sh -c 'curl -O https://raw.githubusercontent.com/torvalds/linux/master/tools/hv/lsvmbus'"
#  	devID=$(ssh -i ~/.ssh/id_rsa tidb@${serverNameIPMap[$key]} "python lsvmbus -vv | grep -w \"Time Synchronization\" -A 3 | grep Device_ID | grep -o '{.*}' | tr -d "{}"")
#	  ssh -i ~/.ssh/id_rsa tidb@${serverNameIPMap[$key]} "sudo sh -c 'echo "$devID" | sudo tee /sys/bus/vmbus/drivers/hv_util/unbind'"
	  ssh -i ~/.ssh/id_rsa tidb@${serverNameIPMap[$key]} "sudo sh -c 'sudo apt-get install ntp ntpstat --assume-yes ; sudo service ntp stop ; sudo ntpd -b time.google.com'"
  	ssh -i ~/.ssh/id_rsa tidb@${serverNameIPMap[$key]} "sudo sh -c 'echo -e \"server time1.google.com iburst\nserver time2.google.com iburst\nserver time3.google.com iburst\nserver time4.google.com iburst\" >> /etc/ntp.conf'"
  	ssh -i ~/.ssh/id_rsa tidb@${serverNameIPMap[$key]} "sudo sh -c 'sudo service ntp start ; ntpstat ; true'"
    scp tidb_mem.yaml tidb@"${serverNameIPMap[$key]}":~/
#    scp tidb_restrict_mem.yaml tidb@"${serverNameIPMap[$key]}":~/
  done
  az vm open-port --resource-group DepFast3 --name tidb"$namePrefix"_pd --port 3000
}

# function run_ssd_experiment {
# 	ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa tidb@$clientPublicIP "(cd ~/ycsb-0.17.0/ ; ./start_experiment.sh $iterations workloads/$workload $ycsbruntime 1 azure noslowfollower disk swapoff 3 $serverRegex $threadsycsb)"
# }

# function run_memory_experiment {
# 	ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa tidb@$clientPublicIP "(cd ~/ycsb-0.17.0/ ; ./start_experiment.sh $iterations workloads/$workload $ycsbruntime 1 azure follower memory swapoff 3 $serverRegex $threadsycsb)"
# }

function setup_client {
  ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa tidb@$clientPublicIP << EOF_1
	sudo apt install git --assume-yes
  sudo apt install wget -y
  wget -q https://dl.google.com/go/go1.12.2.linux-amd64.tar.gz
  tar zxvf go1.12.2.linux-amd64.tar.gz
  sudo mv go /usr/local/
EOF_1

  ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa tidb@$clientPublicIP "sudo sh -c 'sudo echo export GOROOT=/usr/local/go >> /etc/profile'"
#  ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa tidb@$clientPublicIP "sudo sh -c 'sudo echo export GOPATH=\$HOME/go >> /etc/profile'"
  ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa tidb@$clientPublicIP "sudo sh -c 'sudo echo export GOBIN=/usr/local/go/bin >> /etc/profile'"
  ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa tidb@$clientPublicIP "sudo sh -c 'sudo echo export PATH=/usr/local/go:/usr/local/go/bin:\$PATH >> /etc/profile'"
  ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa tidb@$clientPublicIP "source /etc/profile"

  ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa tidb@$clientPublicIP << EOF_1
  sudo apt install make gcc g++ -y
  git clone https://github.com/pingcap/go-ycsb.git /home/tidb/go-ycsb
  cd /home/tidb/go-ycsb
  make
EOF_1
  ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa tidb@$clientPublicIP "sudo sh -c 'sudo echo export PATH=/home/tidb/go-ycsb/bin:\$PATH >> /etc/profile'"
  ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa tidb@$clientPublicIP "source /etc/profile"
  ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa tidb@$clientPublicIP "curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash"
}

function setup_client_az {
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
	ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa tidb@$clientPublicIP "az login --service-principal --username $appID --password $password --tenant $tenantID"
}

function deallocate_vms {
	ns=$(az vm list --query "[].id" --resource-group DepFast3 -o tsv | grep $serverRegex | wc -l)
	if [[ $ns -le 5 ]]
	then
		az vm deallocate --ids $(
			az vm list --query "[].id" --resource-group DepFast3 -o tsv | grep $serverRegex
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
  #setup_localvm    # for debug only
  az_vm_create
  write_config
  find_ip
  setup_servers
  setup_client
#  setup_client_az
  # deallocate_vms

#  if [ "$filesystem" == "disk" ]; then
#	run_ssd_experiment
#  elif [ "$filesystem" == "memory" ]; then
#	run_memory_experiment
#  else
#		echo "This option in filesystem is not supported.Exiting."
#		exit 1
#  fi
}

main
