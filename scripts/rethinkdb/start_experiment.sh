#!/bin/bash

date=$(date +"%Y%m%d%s")
exec > "$date"_experiment.log
exec 2>&1

set -ex

# Server specific configs
##########################
# serverZone="us-central1-a"
resource="DepFast"
clusterPort="29015"
partitionName="/dev/sdc"
###########################

if [ "$#" -ne 9 ]; then
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
serverRegex=$10

declare -A serverNameIPMap 

# test_start is executed at the beginning
function test_start {
	name=$1
	
	echo "Running $exptype experiment $expno for $name"
	dirname="$name"_"$exptype"_"$filesystem"_"$swappiness"_results
	mkdir -p $dirname
}

function set_ip {
	for (( i=0; i<$iterations; i++ ))
	do
		servername=$(cat config.json  | jq .[$i].name)
		servername=$(sed -e "s/^'//" -e "s/'$//" <<<"$servername")
		serverip=$(cat config.json  | jq .[$i].privateip)
		serverip=$(sed -e "s/^'//" -e "s/'$//" <<<"$serverip")
		serverNameIPMap[$servername]=$serverip
	done
}

function setup_ssh_client_servers {
for key in "${!serverNameIPMap[@]}";
do
	ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa "$username"@"$clientPublicIP" "ssh-keygen -R ${serverNameIPMap[$key]} ; ssh-keyscan -H ${serverNameIPMap[$key]} >> ~/.ssh/known_hosts"
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
	        #for cur_s in "${servers[@]}";
	        #do
                #    az vm start --name "$cur_s" --resource-group "$resource"
	        #done
	        az vm start --ids $(
				az vm list --query "[].id" --resource-group DepFast -o tsv | grep $serverRegex
			)

	else
		echo "Not implemented error"
		exit 1
	fi
	sleep 60
}

# init_disk is called to create and mount directories on disk
function init_disk {
	for key in "${!serverNameIPMap[@]}";
	do
		ssh -i ~/.ssh/id_rsa ${serverNameIPMap[$key]} "sudo sh -c 'sudo mkdir -p /data ; sudo mkfs.xfs $partitionName -f ; sudo mount -t xfs $partitionName /data ; sudo mount -t xfs $partitionName /data -o remount,noatime ; sudo chmod o+w /data'"
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
			ssh -i ~/.ssh/id_rsa ${serverNameIPMap[$key]} "sudo sh -c 'sudo dd if=/dev/zero of=/data/swapfile bs=1024 count=41485760 ; sudo chmod 600 /data/swapfile ; sudo mkswap /data/swapfile'"  # 41GB
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
	for key in "${!serverNameIPMap[@]}";
	do
		ssh  -i ~/.ssh/id_rsa ${serverNameIPMap[$key]} "sh -c 'taskset -ac 0 rethinkdb --directory /"$datadir"/rethinkdb_data1 --bind all --server-name ${serverNameIPMap[$key]}  --cache-size 10480 --daemon'"
	done
	sleep 30
}

# db_init initialises the database
function db_init {
	pyserver=${serverNameIPMap[\"rethinkdb"$namePrefix"-1\"]}
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
	./bin/ycsb load rethinkdb -s -P $workload -p rethinkdb.host=$primaryip -p rethinkdb.port=28015 -threads 10
}

# ycsb run exectues the given workload and waits for it to complete
function ycsb_run {
	./bin/ycsb run rethinkdb -s -P $workload -p maxexecutiontime=$ycsbruntime -p rethinkdb.host=$primaryip -p rethinkdb.port=28015 > "$dirname"/exp"$expno"_trial_"$i".txt
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
	source venv/bin/activate ;  python cleanup.py ; deactivate

	if [ "$swappiness" == "swapon" ] ; then
		for key in "${!serverNameIPMap[@]}";
		do
			ssh -i ~/.ssh/id_rsa ${serverNameIPMap[$key]} "sudo sh -c 'pkill rethinkdb ; sudo swapoff -v /data/swapfile'"
		done
	fi 

	for key in "${!serverNameIPMap[@]}";
	do
		ssh -i ~/.ssh/id_rsa ${serverNameIPMap[$key]} "sudo sh -c 'pkill rethinkdb ; sudo rm -rf /data/* ; sudo rm -rf /data/ ; sudo cgdelete cpu:db cpu:cpulow cpu:cpuhigh blkio:db ; true'"
	done
	if [ "$expno" == 6 ]; then
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
	        #for cur_s in "${servers[@]}";
	        #do
	        #    az vm deallocate --name "$cur_s" --resource-group "$resource"
	        #done
	        az vm deallocate --ids $(
			az vm list --query "[].id" --resource-group DepFast -o tsv | grep $serverRegex
		)
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

# Make sure either shutdown is executed after you run this script or uncomment the last line
# sudo shutdown -h now
