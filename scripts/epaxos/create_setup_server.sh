#!/bin/bash

set -ex


# sudo apt-get install git --assume-yes
# git clone https://github.com/Stuart0l/epaxos.git
# wget https://golang.org/dl/go1.15.5.linux-amd64.tar.gz
# sudo tar -C /usr/local -xzf go1.15.5.linux-amd64.tar.gz
# echo "export PATH=\$PATH:/usr/local/go/bin" >> .profile
# echo "export GOPATH=~/epaxos" >> .profile
# source .profile
# cd epaxos/src/client
# go get
# go install client
# go install master

resgrp=(DepFast_ca DepFast_va DepFast_uk DepFast_jp)
cli=(20.57.185.182 40.118.184.215 20.55.99.107 20.90.160.0 20.78.32.192)
# svr=(20.57.185.188 137.135.40.69 20.51.239.69 20.77.50.147 20.78.34.88)
svr=(20.57.185.15 20.57.185.46 20.57.185.82 20.57.185.117 20.57.185.141)

# for (( i=3; i<=5; i++ ))
# do
# 	az network nsg rule create \
# 		--access Allow \
# 		--resource-group ${resgrp[$((i-2))]} \
# 		--nsg-name  andrew-01-janus-ssd-server$((i+2))NSG \
# 		--direction Inbound \
# 		--name AllowAllInbound \
# 		--protocol '*' \
# 		--priority 2000 \
# 		--source-port-ranges '*' \
# 		--destination-port-ranges '*'

# 	az network nsg rule create \
# 		--access Allow \
# 		--resource-group ${resgrp[$((i-2))]} \
# 		--nsg-name  andrew-01-janus-ssd-server$((i+2))NSG \
# 		--direction Outbound \
# 		--name AllowAllOutbound \
# 		--protocol '*' \
# 		--priority 2000 \
# 		--source-port-ranges '*' \
# 		--destination-port-ranges '*'
# done

# az vm create --name andrew-01-janus-ssd-client1 --resource-group DepFast --zone 1 --subscription 'Microsoft Azure Sponsorship 2' --image debian --os-disk-size-gb 64 --storage-sku Standard_LRS  --size Standard_D4s_v3 --admin-username xuhao --ssh-key-values ~/.ssh/id_rsa.pub --accelerated-networking true

for c in ${svr[@]}
do
	scp ~/epaxos/src/epaxos/epaxos.go xuhao@$c:~/epaxos/src/epaxos/
	ssh -o StrictHostKeyChecking=no xuhao@$c "bash --login -c 'export GOPATH=~/epaxos; go install server'"
	# ssh xuhao@$c "bash --login -c 'cd epaxos ; git pull; export GOPATH=~/epaxos; go install client'"
done
