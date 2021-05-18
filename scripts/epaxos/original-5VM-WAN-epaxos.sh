#!/bin/bash

set -ex

if [ "$#" -ne 4 ]; then
	echo "wrong number of args"
	exit 1
fi

grp=$1
name=$2
duration=$3
threads=$4

serverRegex="andrew-$grp-janus-ssd-server[3-7]"
clientRegex="andrew-$grp-janus-ssd-client*"

declare -A serverNameIPMap
declare -A clientNameIPMap
declare -a serverPubIPs
declare -a serverPrIPs

mkdir -p log
exec > >(tee ./log/"$name"_experiment.log) 2>&1

function start_vm {
	az vm start --ids $(az vm list --query "[].id" -o tsv | grep -E "$serverRegex|$clientRegex")
	sleep 15
}

function write_config {
	rm -f *config.json
	az vm list-ip-addresses --ids $(az vm list --query "[].id" -o tsv | grep $clientRegex) --query '[].{name:virtualMachine.name, privateip:virtualMachine.network.privateIpAddresses[0], publicip:virtualMachine.network.publicIpAddresses[0].ipAddress}' -o json > client_config.json
	az vm list-ip-addresses --ids $(az vm list --query "[].id" -o tsv | grep $serverRegex) --query '[].{name:virtualMachine.name, privateip:virtualMachine.network.privateIpAddresses[0], publicip:virtualMachine.network.publicIpAddresses[0].ipAddress}' -o json > server_config.json
}

function set_ip {
	NAME_COUNTER=1

	all_ip=""

	for (( j=0; j<5; j++ ))
	do
		servername=$(cat server_config.json  | jq .[$j].name)
		servername=$(sed -e "s/^'//" -e "s/'$//" <<<"$servername")
		servername=$(sed -e 's/^"//' -e 's/"$//' <<<"$servername")
		serverip=$(cat server_config.json  | jq .[$j].publicip)
		serverip=$(sed -e "s/^'//" -e "s/'$//" <<<"$serverip")
		serverip=$(sed -e 's/^"//' -e 's/"$//' <<<"$serverip")

		clientname=$(cat client_config.json  | jq .[$j].name)
		clientname=$(sed -e "s/^'//" -e "s/'$//" <<<"$clientname")
		clientname=$(sed -e 's/^"//' -e 's/"$//' <<<"$clientname")
		clientip=$(cat client_config.json  | jq .[$j].publicip)
		clientip=$(sed -e "s/^'//" -e "s/'$//" <<<"$clientip")
		clientip=$(sed -e 's/^"//' -e 's/"$//' <<<"$clientip")


		serverNameIPMap[$servername]=$serverip
		echo "server $servername", $serverip

		clientNameIPMap[$clientname]=$clientip
		echo "client $clientname", $clientip

		let NAME_COUNTER=NAME_COUNTER+1

		if [ $j -eq 0 ]; then
			all_ip="$serverip"
		else
			all_ip="$all_ip,$serverip"
		fi
	done

	# master is the first client
	masterip=${clientNameIPMap["andrew-$grp-janus-ssd-client"]}
}

function setup_ssh_client_servers {
	touch ~/.ssh/known_hosts
	for key in "${!clientNameIPMap[@]}";
	do
		ssh-keygen -R ${clientNameIPMap[$key]}
		ssh-keyscan -H ${clientNameIPMap[$key]} >> ~/.ssh/known_hosts
	done
}

function start_master {
	ssh -o StrictHostKeyChecking=no xuhao@$masterip "mkdir -p epaxos/log; sudo pkill master; nohup epaxos/bin/master -ips $all_ip -N 5 > epaxos/log/master.log 2>&1 &"
}

function start_servers {
	for key in ${!serverNameIPMap[@]}
	do
		serverip=${serverNameIPMap[$key]}
		ssh -o StrictHostKeyChecking=no xuhao@$serverip "mkdir -p epaxos/log; sudo pkill server; nohup taskset -ac 0 epaxos/bin/server -e -maddr $masterip -addr $serverip > epaxos/log/server.log 2>&1 &"
	done
}

function run_epaxos {
	for (( i=1; i<=5; i++ ))
	do
		if [ $i -eq 1 ]; then
			clientip=${clientNameIPMap["andrew-$grp-janus-ssd-client"]}
		else
			clientip=${clientNameIPMap["andrew-$grp-janus-ssd-client$i"]}
		fi

		serverip=${serverNameIPMap["andrew-$grp-janus-ssd-server$((i+2))"]}
		
		ssh -o StrictHostKeyChecking=no xuhao@$clientip "mkdir -p epaxos/log; sudo pkill client; cd epaxos; nohup bin/client -l 0 -laddr $serverip -maddr $masterip -T $threads > log/client.log 2>&1 &"
	done

	sleep $duration

	for (( i=1; i<=5; i++ ))
	do
		if [ $i -eq 1 ]; then
			clientip=${clientNameIPMap["andrew-$grp-janus-ssd-client"]}
		else
			clientip=${clientNameIPMap["andrew-$grp-janus-ssd-client$i"]}
		fi
		
		ssh -o StrictHostKeyChecking=no xuhao@$clientip "sudo pkill client; sudo pkill master; mkdir -p backup; python3 epaxos/scripts/client_metrics.py > results/$name.json; mv epaxos/latency.txt backup/latency_$name.txt; mv epaxos/lattput.txt backup/lattput_$name.txt"
	done
}

function clean_up {
	for key in ${!serverNameIPMap[@]}
	do
		serverip=${serverNameIPMap[$key]}
		ssh -o StrictHostKeyChecking=no xuhao@$serverip "sudo pkill server; rm -f stable-store-replica*; rm -f epaxos/stable-store-replica*"
	done

	az vm deallocate --ids $(az vm list --query "[].id" -o tsv | grep -E "$serverRegex|$clientRegex")
}

function test_run {
	
	start_vm
	
	write_config

	set_ip

	setup_ssh_client_servers

	start_master

	start_servers

	run_epaxos

	clean_up
}

test_run
