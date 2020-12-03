#!/usr/local/bin/bash

date=$(date +"%Y%m%d%s")
exec > >(tee "$date"_experiment.log) 2>&1

set -ex

if [ "$#" -ne 2 ]; then
  echo "Wrong number of args"
  echo "1st arg - number of servers to create"
  echo "2nd arg - server prefix name(-1,-2,-3 added as suffix to this name)"
  exit 1
fi

noOfServers=$1
namePrefix=$2

username="riteshsinha"
resource="DepFast3"
serverRegex="etcd$namePrefix-[1-$noOfServers]"
declare -A serverNameIPMap

# Create the VM on Azure
function az_vm_create {
  # Create client VM
  az vm create --name etcd"$namePrefix"-client --resource-group DepFast3 --subscription 'Last Chance' --zone 1 --image debian --os-disk-size-gb 64 --storage-sku Standard_LRS  --size Standard_D4s_v3 --admin-username riteshsinha --ssh-key-values ~/.ssh/id_rsa.pub --accelerated-networking true

  # Setup Client IP and name
  clientConfig=$(az vm list-ip-addresses --name etcd"$namePrefix"-client --query '[0].{name:virtualMachine.name, privateip:virtualMachine.network.privateIpAddresses[0], publicip:virtualMachine.network.publicIpAddresses[0].ipAddress}' -o json)
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
    az vm create --name etcd"$namePrefix"-"$i" --resource-group DepFast3 --subscription 'Last Chance' --zone 1 --image debian --os-disk-size-gb 64 --storage-sku Premium_LRS --data-disk-sizes-gb 64 --size Standard_D4s_v3 --admin-username riteshsinha --ssh-key-values ~/.ssh/id_rsa.pub ./client_rsa.pub --accelerated-networking true
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
}

# Setup the servers to install tools and DB
function setup_servers {
  for key in "${!serverNameIPMap[@]}";
  do
	# Install utilities
    ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa ${serverNameIPMap[$key]} "sudo sh -c 'sudo apt install tmux wget git sysstats htop --assume-yes ; sudo apt-get install cgroup-tools --assume-yes ; sudo apt-get install xfsprogs --assume-yes'"
    scp -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa deadloop "${serverNameIPMap[$key]}":~/
	
	scp -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa install_etcd.sh "${serverNameIPMap[$key]}":~/
	# Install etcd
	ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa ${serverNameIPMap[$key]} "sudo sh -c './install_etcd.sh'"
	
  done
}

function setup_client {
    # SCP the experiment files to the client. This should run from the script/etcd path
	scp -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa -r ./* $clientPublicIP:~/

	scp -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa -r install_etcd.sh $clientPublicIP:~/
	# Install etcd
	ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa $clientPublicIP "sudo sh -c './install_etcd.sh'"

    ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa $clientPublicIP "sudo sh -c 'sudo apt install tmux wget git htop jq --assume-yes'"
	# Install go
	ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa $clientPublicIP "sudo sh -c ' wget https://golang.org/dl/go1.15.5.linux-amd64.tar.gz; tar -C /usr/local -xzf go1.15.5.linux-amd64.tar.gz; export PATH=$PATH:/usr/local/go/bin; echo "PATH=\$PATH:/usr/local/go/bin" >> .bashrc ; echo "PATH=\$PATH:/usr/local/go/bin" >> .bash_profile ; echo "GOPATH=./" >> .bashrc '"

	ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa $clientPublicIP "sudo /bin/bash --login -c 'go version'"

	# Install benchmark tool
	ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa $clientPublicIP "sudo /bin/bash --login -c 'git clone https://github.com/etcd-io/etcd.git ; cd etcd; go install -v ./tools/benchmark'"

	ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa $clientPublicIP "sudo /bin/bash --login -c 'echo "PATH=\$PATH:./go/bin/" >> .bashrc ; echo "PATH=\$PATH:./go/bin/" >> .bash_profile'"

	ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa $clientPublicIP "sudo /bin/bash --login -c 'sudo curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash'"
}

function main {
  az_vm_create

  write_config

  find_ip

  setup_servers

  setup_client

  echo "Client and server setup done for etcd."
}

main
