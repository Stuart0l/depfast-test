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

serverRegex="andrew-$grp-janus-ssd-server[1-3]"

declare -a serverPubIPs
declare -a serverPrIPs

mkdir -p log
exec > >(tee ./log/"$name"_experiment.log) 2>&1

function start_vm {
	az vm start --ids $(az vm list --query "[].id" -o tsv | grep "andrew-$grp-janus-ssd")
	sleep 15
}

function write_config {
	rm -f config.json
	az vm list-ip-addresses --ids $(az vm list --query "[].id" --resource-group DepFast -o tsv | grep $serverRegex) --query '[].{name:virtualMachine.name, privateip:virtualMachine.network.privateIpAddresses[0], publicip:virtualMachine.network.publicIpAddresses[0].ipAddress}' -o json > config.json
}

function set_ip {
	NAME_COUNTER=1
	cli_pr_ip=`az vm list-ip-addresses -g DepFast -n andrew-$grp-janus-ssd-client --query [0].virtualMachine.network.privateIpAddresses[0] -o tsv`
	cli_pub_ip=`az vm list-ip-addresses -g DepFast -n andrew-$grp-janus-ssd-client --query [0].virtualMachine.network.publicIpAddresses[0].ipAddress -o tsv`

	all_ip=""

	for (( j=0; j<3; j++ ))
	do
		server_pub_ip=$(cat config.json  | jq .[$j].publicip)
		server_pub_ip=$(sed -e "s/^'//" -e "s/'$//" <<<"$server_pub_ip")
		server_pub_ip=$(sed -e 's/^"//' -e 's/"$//' <<<"$server_pub_ip")
		server_pr_ip=$(cat config.json  | jq .[$j].privateip)
		server_pr_ip=$(sed -e "s/^'//" -e "s/'$//" <<<"$server_pr_ip")
		server_pr_ip=$(sed -e 's/^"//' -e 's/"$//' <<<"$server_pr_ip")

		serverPubIPs[$j]=$server_pub_ip
		serverPrIPs[$j]=$server_pr_ip

		let NAME_COUNTER=NAME_COUNTER+1

		if [ $j -eq 0 ]; then
			all_ip="$server_pr_ip"
		else
			all_ip="$all_ip,$server_pr_ip"
		fi
	done
}

function start_master {
	ssh -o StrictHostKeyChecking=no xuhao@$cli_pub_ip "mkdir -p epaxos/log; nohup epaxos/bin/master -ips $all_ip > epaxos/log/master.log 2>&1 &"
}

function start_servers {
	for (( j=0; j<3; j++ ))
	do
	ssh -o StrictHostKeyChecking=no xuhao@${serverPubIPs[$j]} "mkdir -p epaxos/log; nohup taskset -ac 0 epaxos/bin/server -e -maddr $cli_pr_ip -addr ${serverPrIPs[$j]} > epaxos/log/server.log 2>&1 &"
	done
}

function run_epaxos {
	ssh -o StrictHostKeyChecking=no xuhao@$cli_pub_ip "cd epaxos; nohup bin/client -l 0 -T $threads > log/client.log 2>&1 &"

	sleep $duration

	ssh -o StrictHostKeyChecking=no xuhao@$cli_pub_ip "sudo pkill client; sudo pkill master; python3 epaxos/scripts/client_metrics.py > results/$name.json; mv epaxos/latency.txt backup/latency_$name.txt; mv epaxos/lattput.txt backup/lattput_$name.txt"
}

function clean_up {
	for (( j=0; j<3; j++))
	do
		ssh -o StrictHostKeyChecking=no xuhao@${serverPubIPs[$j]} "sudo pkill server; rm -f stable-store-replica*; rm -f epaxos/stable-store-replica*"
	done

	az vm deallocate --ids $(az vm list --query "[].id" -o tsv | grep "andrew-$grp-janus-ssd")
}

function test_run {
	
	start_vm
	
	write_config

	set_ip

	start_master

	start_servers

	run_epaxos

	clean_up
}

test_run
