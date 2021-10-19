#!/bin/bash

set -ex

if [ "$#" -ne 7 ]; then
	echo "wrong number of args"
	exit 1
fi

grp=$1
name=$2
duration=$3
poisson=$4
oreq=$5
conf=$6
threads=$7

serverRegex="andrew-$grp-janus-ssd-server[1-5]"
clientRegex="andrew-$grp-janus-ssd-client"

declare -A serverNameIPMap
declare -A serverNamePriIPMap
declare -A clientNameIPMap
declare -a serverPubIPs
declare -a serverPrIPs

if [ $threads -ne 0 ]; then
	mkdir -p log
	exec > >(tee ./log/"$name"_experiment.log) 2>&1
fi

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
		serverippri=$(cat server_config.json  | jq .[$j].privateip)
		serverippri=$(sed -e "s/^'//" -e "s/'$//" <<<"$serverippri")
		serverippri=$(sed -e 's/^"//' -e 's/"$//' <<<"$serverippri")

		if [ $j -eq 0 ]; then
			clientname=$(cat client_config.json  | jq .[$j].name)
			clientname=$(sed -e "s/^'//" -e "s/'$//" <<<"$clientname")
			clientname=$(sed -e 's/^"//' -e 's/"$//' <<<"$clientname")
			clientip=$(cat client_config.json  | jq .[$j].publicip)
			clientip=$(sed -e "s/^'//" -e "s/'$//" <<<"$clientip")
			clientip=$(sed -e 's/^"//' -e 's/"$//' <<<"$clientip")
			clientippri=$(cat client_config.json  | jq .[$j].privateip)
			clientippri=$(sed -e "s/^'//" -e "s/'$//" <<<"$clientippri")
			clientippri=$(sed -e 's/^"//' -e 's/"$//' <<<"$clientippri")

			masterip=$clientip
			masterippri=$clientippri
			echo "client $clientname", $clientip, $clientippri
		fi


		serverNameIPMap[$servername]=$serverip
		serverNamePriIPMap[$servername]=$serverippri
		echo "server $servername", $serverip, $serverippri

		let NAME_COUNTER=NAME_COUNTER+1

		if [ $j -eq 0 ]; then
			all_ip="$serverippri"
		else
			all_ip="$all_ip,$serverippri"
		fi
	done

	# master is the first client
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
		serverippri=${serverNamePriIPMap[$key]}
		ssh -o StrictHostKeyChecking=no xuhao@$serverip "mkdir -p epaxos/log; sudo pkill server; ulimit -n 32768;  nohup epaxos/bin/server -e -exec -dreply -thrifty -maddr $masterippri -addr $serverippri > epaxos/log/server.log 2>&1 &"
		# ssh -o StrictHostKeyChecking=no xuhao@$serverip "mkdir -p epaxos_new/log; sudo pkill server; ulimit -n 32768;  nohup epaxos_new/bin/server -e -maddr $masterip -addr $serverip > epaxos_new/log/server.log 2>&1 &"
	done
}

function run_epaxos {
	for (( i=1; i<=5; i++ ))
	do
		clientip=${clientNameIPMap["andrew-$grp-janus-ssd-client$i"]}

		serverip=${serverNameIPMap["andrew-$grp-janus-ssd-server$((i+2))"]}
		
		# zipfian skew 0.9, 1,000,000 keys, 50% writes, 10 clients
		# ssh -o StrictHostKeyChecking=no xuhao@$clientip "mkdir -p epaxos/log; sudo pkill client; cd epaxos; ulimit -n 32768; nohup bin/client -l 0 -laddr $serverip -maddr $masterip -poisson $poisson -or $oreq -c -1 -theta 0.9 -z 1000000 -writes 0.5 -T $threads > log/client.log 2>&1 &"
		ssh -o StrictHostKeyChecking=no xuhao@$clientip "mkdir -p epaxos/log; sudo pkill client; cd epaxos; ulimit -n 32768; nohup bin/client -id $((i-1)) -l 0 -laddr $serverip -maddr $masterip -poisson $poisson -or $oreq -c $conf -writes 1 -T $threads > log/client.log 2>&1 &"
	done

	sleep $duration
	mkdir -p results/$name

	for (( i=1; i<=5; i++ ))
	do
		clientip=${clientNameIPMap["andrew-$grp-janus-ssd-client$i"]}
		if [ $i -eq 1 ]; then
			ssh -o StrictHostKeyChecking=no xuhao@$clientip "sudo pkill client; sudo pkill master"
		else
			ssh -o StrictHostKeyChecking=no xuhao@$clientip "sudo pkill client"
		fi
	done

	for (( i=1; i<=5; i++ ))
	do
		clientip=${clientNameIPMap["andrew-$grp-janus-ssd-client$i"]}
		
		ssh -o StrictHostKeyChecking=no xuhao@$clientip " mkdir -p backup; mkdir -p results; python3 epaxos/scripts/client_metrics.py > results/$name.json; cat results/$name.json"
		scp xuhao@$clientip:~/results/$name.json results/$name/$i.json
		scp xuhao@$clientip:~/lattime.png results/$name/$i.png
	done
}

function clean_up {
	for key in ${!serverNameIPMap[@]}
	do
		serverip=${serverNameIPMap[$key]}
		ssh -o StrictHostKeyChecking=no xuhao@$serverip "sudo pkill server; rm -f stable-store-replica*; rm -f epaxos/stable-store-replica*"
	done

	# az vm deallocate --ids $(az vm list --query "[].id" -o tsv | grep -E "$serverRegex|$clientRegex")
}

function test_run {
	
	start_vm
	
	write_config

	set_ip

	## setup_ssh_client_servers

	start_master

	start_servers

	# run_epaxos

	# clean_up
}

if [ $threads -eq 0 ]; then
	set_ip
	clean_up
else
	test_run
fi
