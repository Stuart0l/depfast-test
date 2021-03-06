#!/bin/bash

date=$(date +"%Y%m%d%s")
exec > "$date"_experiment.log
exec 2>&1

set -ex

# Server specific configs
##########################
resource="DepFast3"
clusterPort="29015"
partitionName="/dev/sdc"
###########################

if [ "$#" -ne 11 ]; then
    echo "Wrong number of parameters"
    echo "1st arg - number of iterations"
    echo "2nd arg - workload path"
    echo "3rd arg - seconds to run ycsb run"
    echo "4th arg - experiment to run(1,2,3,4,5,6)"
    echo "5th arg - host type(gcp/azure)"
    echo "6th arg - type of experiment(follower,leader,noslow)"
	echo "7th arg - file system to use(disk,memory)"
	echo "8th arg - vm swappiness parameter(swapoff,swapon)[swapon only for exp6+mem]"
	echo "9th arg - no of servers(3/5)"
	echo "10th arg - server Regex"
	echo "11th arg - threads for ycsb run(for saturation exp)"
    exit 1
fi

iterations=$1
workload=$2
ycsbruntime=$3
expno=$4
host=$5
exptype=$6
filesystem=$7
swappiness=$8
noOfServers=$9
serverRegex=${10}
ycsbthreads=${11}

declare -A serverNameIPMap 

# test_start is executed at the beginning
function test_start {
	name=$1
	
	echo "Running $exptype experiment $expno for $name"
	dirname="$name"_"$exptype"_"$filesystem"_"$swappiness"_results
	mkdir -p $dirname
}

function set_ip {
	for (( j=0; j<$noOfServers; j++ ))
	do
		servername=$(cat config.json  | jq .[$j].name)
		servername=$(sed -e "s/^'//" -e "s/'$//" <<<"$servername")
  		servername=$(sed -e 's/^"//' -e 's/"$//' <<<"$servername")
		serverip=$(cat config.json  | jq .[$j].privateip)
		serverip=$(sed -e "s/^'//" -e "s/'$//" <<<"$serverip")
  		serverip=$(sed -e 's/^"//' -e 's/"$//' <<<"$serverip")
		serverNameIPMap[$servername]=$serverip
		pyserver=$serverip
	done
}

function setup_ssh_client_servers {
	touch ~/.ssh/known_hosts
	for key in "${!serverNameIPMap[@]}";
	do
		ssh-keygen -R ${serverNameIPMap[$key]}
		ssh-keyscan -H ${serverNameIPMap[$key]} >> ~/.ssh/known_hosts
	done
}

# data_cleanup is called just after servers start
function data_cleanup {
	for key in "${!serverNameIPMap[@]}";
	do
		ssh -i ~/.ssh/id_rsa ${serverNameIPMap[$key]} "sh -c 'rm -rf /data/*'"
	done
}

# start_servers is used to boot the servers up
function start_servers {	
	if [ "$host" == "gcp" ]; then
		gcloud compute instances start ${!serverNameIPMap[@]}

	elif [ "$host" == "azure" ]; then
			# For regex have the following check to save ourselves from malformed regex which can lead
			# to starting of non-target VMs
			ns=$(az vm list --query "[].id" --resource-group DepFast3 -o tsv | grep $serverRegex | wc -l)
			if [[ $ns -le 5 ]]
			then
				az vm start --ids $(
					az vm list --query "[].id" --resource-group DepFast3 -o tsv | grep $serverRegex
				)
			else
				echo "Server regex malformed, performing linear start"
				# Switching back to linear start
				for key in "${!serverNameIPMap[@]}";
				do
					az vm start --name "$key" --resource-group "$resource"
				done
			fi
	else
		echo "Not implemented error"
		exit 1
	fi
	sleep 30
}

# init_disk is called to create and mount directories on disk
function init_disk {
	for key in "${!serverNameIPMap[@]}";
	do
		ssh -i ~/.ssh/id_rsa ${serverNameIPMap[$key]} "sudo sh -c 'sudo mkdir -p /data ; sudo mkfs.xfs $partitionName -f ; sudo mount -t xfs $partitionName /data ; sudo mount -t xfs $partitionName /data -o remount,noatime ; sudo chmod o+w /data'"

		# If, experiment4, create the file beforehand to which the dd command should write to.
		# NOTE - The count value should be same as the one mentioned in launch_dd.sh script
		if [ "$expno" == 4 ]; then
			ssh -i ~/.ssh/id_rsa ${serverNameIPMap[$key]} "sh -c 'taskset -ac 1 dd if=/dev/zero of=/data/tmp.txt bs=1000 count=1800000 conv=notrunc'"
		fi
		
	done
	
}

function set_swap_config {
	# swappiness config
	if [ "$swappiness" == "swapoff" ] ; then
		for key in "${!serverNameIPMap[@]}";
		do
			ssh -i ~/.ssh/id_rsa ${serverNameIPMap[$key]} "sudo sh -c 'sudo sysctl vm.swappiness=0 ; sudo swapoff -a && swapon -a'"
		done
	elif [ "$swappiness" == "swapon" ] ; then
		# Disk needed for swapfile
		init_disk
		
		for key in "${!serverNameIPMap[@]}";
		do
			ssh -i ~/.ssh/id_rsa ${serverNameIPMap[$key]} "sudo sh -c 'sudo dd if=/dev/zero of=/data/swapfile bs=1024 count=25165824 ; sudo chmod 600 /data/swapfile ; sudo mkswap /data/swapfile'"  # 24 GB
			ssh -i ~/.ssh/id_rsa ${serverNameIPMap[$key]} "sudo sh -c 'sudo sysctl vm.swappiness=60 ; sudo swapoff -a && sudo swapon -a ; sudo swapon /data/swapfile'"
		done
	else
		echo "swappiness option not recognised. Exiting."
		exit 1
	fi
}

# init_memory is called to create and mount memory based file system(tmpfs)
function init_memory {
	# Mount tmpfs
	for key in "${!serverNameIPMap[@]}";
	do
		ssh -i ~/.ssh/id_rsa ${serverNameIPMap[$key]} "sudo sh -c 'sudo mkdir -p /ramdisk ; sudo mount -t tmpfs -o rw,size=8G tmpfs /ramdisk/ ; sudo chmod o+w /ramdisk/'"	
	done
}

# start_db starts the database instances on each of the server
function start_db {
	COUNTER=0
	for key in "${!serverNameIPMap[@]}";
	do
		if [ $COUNTER -eq 0 ];
		then
			ssh -i ~/.ssh/id_rsa ${serverNameIPMap[$key]} "sh -c 'taskset -ac 0 rethinkdb --directory /"$datadir"/rethinkdb_data1 --bind all --server-name $key --daemon'"
			joinIP=${serverNameIPMap[$key]}
		else
			ssh -i ~/.ssh/id_rsa ${serverNameIPMap[$key]} "sh -c 'taskset -ac 0 rethinkdb --directory /"$datadir"/rethinkdb_data1 --join "$joinIP":"$clusterPort" --bind all --server-name $key --daemon'"
		fi
		let COUNTER=COUNTER+1
	done
	sleep 20
}

# db_init initialises the database
function db_init {
	source venv/bin/activate ;  python initr.py $pyserver  > tablesinfo ; deactivate
	sleep 5
	primaryreplica=$(cat tablesinfo | grep -Eo 'primaryreplica=.{1,50}' | cut -d'=' -f2-)
	echo $primaryreplica

	secondaryreplica=$(cat tablesinfo | grep -Eo 'secondaryreplica=.{1,50}' | cut -d'=' -f2-)
	echo $secondaryreplica

	primarypid=$(cat tablesinfo | grep -Eo 'primarypid=.{1,10}' | cut -d'=' -f2-)
	echo $primarypid

	secondarypid=$(cat tablesinfo | grep -Eo 'secondarypid=.{1,10}' | cut -d'=' -f2-)
	echo $secondarypid

	primaryip=$(cat tablesinfo | grep -Eo 'primaryip=.{1,30}' | cut -d'=' -f2-)
	echo $primaryip

	secondaryip=$(cat tablesinfo | grep -Eo 'secondaryip=.{1,30}' | cut -d'=' -f2-)
	echo $secondaryip

	# TODO - Capture two followers here
	# TODO - Slow down multiple nodes for 5 nodes

	if [ "$exptype" == "follower" ]; then
		slowdownpid=$secondarypid
		slowdownip=$secondaryip
	elif [ "$exptype" == "leader" ]; then
		slowdownpid=$primarypid
		slowdownip=$primaryip
	else
		echo ""
	fi
}

# ycsb_load is used to run the ycsb load and wait until it completes.
function ycsb_load {
	./bin/ycsb load rethinkdb -s -P $workload -p rethinkdb.host=$primaryip -p rethinkdb.port=28015 -threads 20
}

# ycsb run exectues the given workload and waits for it to complete
function ycsb_run {
	./bin/ycsb run rethinkdb -s -P $workload -p maxexecutiontime=$ycsbruntime -p rethinkdb.host=$primaryip -p rethinkdb.port=28015 -threads $ycsbthreads > "$dirname"/exp"$expno"_trial_"$i".txt
}

# cleanup is called at the end of the given trial of an experiment
function cleanup_disk {
	source venv/bin/activate ; python cleanup.py $pyserver; deactivate
	for key in "${!serverNameIPMap[@]}";
	do
		ssh -i ~/.ssh/id_rsa ${serverNameIPMap[$key]} "sudo sh -c 'pkill rethinkdb ; sudo rm -rf /data/* ; sudo rm -rf /data/ ; sudo umount $partitionName ; sudo cgdelete cpu:db cpu:cpulow cpu:cpuhigh blkio:db ; true'"
	done
	# Remove the tc rule for exp 5
	if [ "$expno" == 5 -a "$exptype" != "noslow" ]; then
		ssh -i ~/.ssh/id_rsa "$slowdownip" "sudo sh -c 'sudo /sbin/tc qdisc del dev eth0 root ; true'"
	fi
	rm tablesinfo
	sleep 5
}

function cleanup_memory {
	source venv/bin/activate ;  python cleanup.py $pyserver; deactivate

	if [ "$swappiness" == "swapon" ] ; then
		for key in "${!serverNameIPMap[@]}";
		do
			ssh -i ~/.ssh/id_rsa ${serverNameIPMap[$key]} "sudo sh -c 'pkill rethinkdb ; sudo swapoff -v /data/swapfile'"
		done
	fi 

	for key in "${!serverNameIPMap[@]}";
	do
		ssh -i ~/.ssh/id_rsa ${serverNameIPMap[$key]} "sudo sh -c 'pkill rethinkdb ; sudo rm -rf /data/* ; sudo rm -rf /data/ ; sudo cgdelete cpu:db cpu:cpulow cpu:cpuhigh blkio:db memory:db; true'"
	done
	if [ "$swappiness" == "swapon" ]; then
		for key in "${!serverNameIPMap[@]}";
		do
			ssh -i ~/.ssh/id_rsa ${serverNameIPMap[$key]} "sudo sh -c 'sudo umount $partitionName'"
		done
	fi
	# Remove the tc rule for exp 5
	if [ "$expno" == 5 -a "$exptype" != "noslow" ]; then
		ssh -i ~/.ssh/id_rsa "$slowdownip" "sudo sh -c 'sudo /sbin/tc qdisc del dev eth0 root ; true'"
	fi
	rm tablesinfo
	sleep 5
}

# stop_servers turns off the VM instances
function stop_servers {
	if [ "$host" == "gcp" ]; then
		gcloud compute instances stop ${!serverNameIPMap[@]}
	elif [ "$host" == "azure" ]; then
	    # For regex have the following check to save ourselves from malformed regex which can lead
		# to stopping of non-target VMs
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
	else
		echo "Not implemented error"
		exit 1
	fi
}

# run_experiment executes the given experiment
function run_experiment {
	# TODO - If there are 5 VMs, multiple nodes need to be slowed down
	./experiment$expno.sh "$slowdownip" "$slowdownpid"
}

# test_run is the main driver function
function test_run {
	for (( i=1; i<=$iterations; i++ ))
	do
		echo "Running experiment $expno - Trial $i"
		# 1. start servers
		start_servers

		# 2. Set IP addresses
		set_ip

		# 3. Copy ssh keys
		setup_ssh_client_servers

		# 4. Cleanup first
		data_cleanup	

		# 5. Create data directories
		datadir="data"
		if [ "$filesystem" == "disk" ]; then
			init_disk	
		elif [ "$filesystem" == "memory" ]; then
			datadir="ramdisk"
			init_memory
		else
			echo "This option in filesystem is not supported.Exiting."
			exit 1
		fi

		# 6. Set swappiness config
		set_swap_config

		# 7. SSH to all the machines and start db
		start_db

		# 8. Init
		db_init

		# 9. ycsb load
		ycsb_load

		# 10. Run experiment if this is not a no slow
		if [ "$exptype" != "noslow" ]; then
			run_experiment
		fi

		# 11. ycsb run
		ycsb_run

		# 12. cleanup
		if [ "$filesystem" == "disk" ]; then
			cleanup_disk
		elif [ "$filesystem" == "memory" ]; then
			cleanup_memory
		else
			echo "This option in filesystem is not supported.Exiting."
			exit 1
		fi
		
		# 13. Power off all the VMs
		stop_servers
	done
}

test_start rethinkdb
test_run
