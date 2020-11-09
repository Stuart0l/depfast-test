#!/bin/bash

set -ex

if [ "$#" -ne 8 ]; then
	echo "Wrong number of args"
	echo "1st arg - number of iterations"
	echo "2nd arg - seconds to run ycsb"
	echo "3rd arg - experiment to run(1,2,3,4,5,6), for no slow, use any"
	echo "4th arg - type of experiment(follower/noslowfollower/maxthroughput/noslowmaxthroughput)"
	echo "5th arg - file system to use(disk/memory)"
	echo "6th arg - vm swappiness(swapoff/swapon)"
	echo "7th arg - server regex"
	echo "8th arg - threads for ycsb(saturation experiment)"
	exit 1
fi

iterations=$1
ycsbruntime=$2
expno=$3
exptype=$4
filesystem=$5
swappiness=$6
serverRegex=$7
ycsbthreads=$8

# Find client VM IP
client_ip=`az vm list-ip-addresses -g DepFast3 -n cockroachdb$serverRegex-client --query [0].virtualMachine.network.publicIpAddresses[0].ipAddress -o tsv`

# Start the client VM
az vm start --ids $( az vm list --query "[].id" --resource-group DepFast3 -o tsv | grep cockroachdb$serverRegex-client)

# Wait for sshd to load on client VM
sleep 10s

# ssh to client vm and run experiment
# NOTE - the stdout of start_experiment is displayed on terminal as well as redirected to <timestamp>_experiment.log under ycsb directory on client VM.
ssh -o StrictHostKeyChecking=no -t $client_ip "sh -c 'cd ~/ycsb-0.17.0/ ; ./start_experiment.sh $iterations workloads/workloada_more $ycsbruntime $expno azure $exptype $filesystem $swappiness 3 cockroachdb$serverRegex-[1-3] $ycsbthreads'"

# scp the given experiment results to ../../results/saturate_ssd/cockroachdb
# Note - this will remove the current results and scp the results from client VM
if [ $ycsbthreads -gt 1 ]; then
	echo "scp saturate ssd results"
	cd ../../results/saturate_ssd/cockroachdb ; rm -rf cockroachdb_"$exptype"_"$filesystem"_"$swappiness"_results/ ; scp -r $client_ip:~/ycsb-0.17.0/cockroachdb_"$exptype"_"$filesystem"_"$swappiness"_results/ ./
else
	echo "scp 1 client ssd results results"
	cd ../../results/1client_ssd/cockroachdb ; rm -rf cockroachdb_"$exptype"_"$filesystem"_"$swappiness"_results/ ; scp -r $client_ip:~/ycsb-0.17.0/cockroachdb_"$exptype"_"$filesystem"_"$swappiness"_results/ ./
fi

# servers gets stopped by start_experiment.sh script
# Stop the client VM here
az vm stop --ids $( az vm list --query "[].id" --resource-group DepFast3 -o tsv | grep cockroachdb$serverRegex-client)
az vm deallocate --ids $( az vm list --query "[].id" --resource-group DepFast3 -o tsv | grep cockroachdb$serverRegex-client)

# Run parse.py to generate report
cd ../../results ; python3 parse.py 
