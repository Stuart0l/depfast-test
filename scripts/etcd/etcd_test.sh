#!/bin/bash

date=$(date +"%Y%m%d%s")
exec > >(tee "$date"_experiment.log) 2>&1

set -ex

# Server specific configs
##########################
serverZone="us-central1-a"
nic="eth0"
partitionName="/dev/sdc"
# Azure support
resource="DepFast3"
tppattern="[max|min]throughput"
###########################

if [ "$#" -ne 11 ]; then
    echo "Wrong number of parameters"
    echo "1st arg - number of iterations"
    echo "2nd arg - workload path"
    echo "3rd arg - seconds to run ycsb run"
    echo "4th arg - experiment to run(1,2,3,4,5,6)"
    echo "5th arg - host type(gcp/azure)"
    echo "6th arg - type of experiment(follower/maxthroughput/minthroughput/noslowfolllower/noslowmaxthroughput/noslowminthroughput)"
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

# Map to keep track of server names to ip address
declare -A serverNameIPMap
# Map to keep track of server names to the datacenter names
declare -A serverNameDCname

declare -a servernames
declare -a serverips
declare -a serverdcnames

# test_start is executed at the beginning
function test_start {
	name=$1
	
	echo "Running $exptype experiment $expno for $name"
	dirname="$name"_"$exptype"_"$filesystem"_"$swappiness"_results
	mkdir -p $dirname
}

function set_ip {
	NAME_COUNTER=1
	for (( j=0; j<$noOfServers; j++ ))
	do
		servername=$(cat config.json  | jq .[$j].name)
		servername=$(sed -e "s/^'//" -e "s/'$//" <<<"$servername")
		servername=$(sed -e 's/^"//' -e 's/"$//' <<<"$servername")
		serverip=$(cat config.json  | jq .[$j].privateip)
		serverip=$(sed -e "s/^'//" -e "s/'$//" <<<"$serverip")
		serverip=$(sed -e 's/^"//' -e 's/"$//' <<<"$serverip")

		serverNameIPMap[$servername]=$serverip
		# Set serverNameDCname map
		serverNameDCname[$servername]="us-$NAME_COUNTER"
		if [ $j -eq 0 ];then
			initserver=$serverip
		fi
		echo "$servername", $serverip
		servernames[$j]=$servername
		serverips[$j]=$serverip
		serverdcnames[$j]="us-$NAME_COUNTER"

		let NAME_COUNTER=NAME_COUNTER+1
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
	sleep 45s
	for key in "${!serverNameIPMap[@]}";
	do
		ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa ${serverNameIPMap[$key]} "sh -c 'rm -rf /data/*'"
	done
}

# start_servers is used to boot the servers up
function start_servers {	
	if [ "$host" == "gcp" ]; then
		gcloud compute instances start ${!serverNameIPMap[@]} --zone="$serverZone"
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
	sleep 5
}

# init_disk is called to create and mount directories on disk
function init_disk {
    for key in "${!serverNameIPMap[@]}";
    do
        ssh -i ~/.ssh/id_rsa ${serverNameIPMap[$key]} "sudo sh -c 'sudo mkdir -p /data ; sudo mkfs.xfs $partitionName -f ; sudo mount -t xfs $partitionName /data ; sudo mount -t xfs $partitionName /data -o remount,noatime ; sudo chmod o+w /data'"

		# If, experiment4, create the file beforehand to which the dd command should write to.
		# NOTE - The count value should be same as the one mentioned in launch_dd.sh script
		#if [ "$expno" == 4 ]; then
		#	ssh -i ~/.ssh/id_rsa ${serverNameIPMap[$key]} "sh -c 'taskset -ac 1 dd if=/dev/zero of=/data/tmp.txt bs=1000 count=1800000 conv=notrunc'"
		#fi
    done
}

# init_memory is called to create and mount memory based file system(tmpfs)
function init_memory {
    for key in "${!serverNameIPMap[@]}";
    do
        ssh -i ~/.ssh/id_rsa ${serverNameIPMap[$key]} "sudo sh -c 'sudo mkdir -p /ramdisk ; sudo mount -t tmpfs -o rw,size=8G tmpfs /ramdisk/ ; sudo chmod o+w /ramdisk/'"	
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
		if [ "$filesystem" == "memory" ]; then
			init_disk
		fi
		for key in "${!serverNameIPMap[@]}";
		do
		    ssh -i ~/.ssh/id_rsa ${serverNameIPMap[$key]} "sudo sh -c 'sudo dd if=/dev/zero of=/data/swapfile bs=1024 count=25165824 ; sudo chmod 600 /data/swapfile ; sudo mkswap /data/swapfile'"  # 24GB
		    ssh -i ~/.ssh/id_rsa ${serverNameIPMap[$key]} "sudo sh -c 'sudo sysctl vm.swappiness=60 ; sudo swapoff -a && sudo swapon -a ; sudo swapon /data/swapfile'"
		done
	else
		echo "swappiness option not recognised. Exiting."
		exit 1
	fi
}

function join_by { local IFS="$1"; shift; echo "$*"; }

function setup_etcd {
   TOKEN=token-01
   CLUSTER_STATE=new
   # Name is hostname
   NAME_1=${servernames[0]}
   NAME_2=${servernames[1]}
   NAME_3=${servernames[2]}
   # Host is ip
   HOST_1=${serverips[0]}
   HOST_2=${serverips[1]}
   HOST_3=${serverips[2]}
   CLUSTER=${NAME_1}=http://${HOST_1}:2380,${NAME_2}=http://${HOST_2}:2380,${NAME_3}=http://${HOST_3}:2380
    export ETCDCTL_API=3
    ENDPOINTS=$HOST_1:2379,$HOST_2:2379,$HOST_3:2379
}

function start_etcd {
    for (( r=0; r<$noOfServers;r++ )); 
    do  
	THIS_NAME=${servernames[$r]}
	THIS_IP=${serverips[$r]}
	ssh  -i ~/.ssh/id_rsa ${serverips[$r]} "sh -c 'nohup taskset -ac 0 etcd --data-dir=/data/data.etcd --name ${THIS_NAME} --initial-advertise-peer-urls http://${THIS_IP}:2380 --listen-peer-urls http://${THIS_IP}:2380 --advertise-client-urls http://${THIS_IP}:2379 --listen-client-urls http://${THIS_IP}:2379 --initial-cluster ${CLUSTER} --initial-cluster-state ${CLUSTER_STATE} --initial-cluster-token ${TOKEN} > /dev/null 2>&1 &'"

    done

    sleep 5s

    # Check status
    etcdctl --write-out=table --endpoints=$ENDPOINTS endpoint status
}

function find_follower_leader {
	rm -f etcd.json jsonres

        etcdctl --write-out=json --endpoints=$ENDPOINTS endpoint status > etcd.json

	python3 etcd_helper.py etcd.json > jsonres

	primaryip=$(cat jsonres | grep -Eo 'leader=.{1,30}' | cut -d'=' -f2-)
	secondaryip=$(cat jsonres | grep -Eo 'follower=.{1,30}' | cut -d'=' -f2-)

	primarypid=$(ssh -i ~/.ssh/id_rsa "$primaryip" "sh -c 'pgrep etcd'")
	secondarypid=$(ssh -i ~/.ssh/id_rsa "$secondaryip" "sh -c 'pgrep etcd'")

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

function load_benchmark {
	benchmark --endpoints=$primaryip:2380 --target-leader --conns=100 --clients=1000 put --key-size=8 --total=1000000 --val-size=256
}

function run_benchmark {
	date_run=$(date +"%Y%m%d%s")
	benchmark --endpoints=$primaryip:2380 --target-leader --conns=100 --clients=1000 put --key-size=8 --total=1000000 --val-size=256 > "$dirname"/exp"$expno"_trial_"$i"_"$date_run".txt
}

# cleanup_disk is called at the end of the given trial of an experiment
function cleanup_disk {
    for key in "${!serverNameIPMap[@]}";
    do
        ssh -i ~/.ssh/id_rsa "${serverNameIPMap[$key]}" "sudo sh -c 'pkill etcd ; sudo pkill dd; sudo rm -rf /data/*; sudo rm -rf /data ; sudo umount $partitionName ; sudo rm -rf /data/ ; sudo cgdelete cpu:db cpu:cpulow cpu:cpuhigh blkio:db memory:db; true'"
    done

	# Remove the tc rule for exp 5
	if [ "$expno" == 5 -a "$exptype" != "noslowfollower" ]; then
		if [ "$exptype" != "noslowmaxthroughput" -a "$exptype" != "noslowminthroughput" ]; then
		  ssh -i ~/.ssh/id_rsa "$slowdownip" "sudo sh -c 'sudo /sbin/tc qdisc del dev "$nic" root ; true'"
		fi  
	fi  
}

function stop_servers {
	if [ "$host" == "gcp" ]; then
        gcloud compute instances stop ${!serverNameIPMap[@]}  --zone="$serverZone"
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

		setup_etcd

		# 7. SSH to all the machines and start db
		start_etcd

		find_follower_leader

		load_benchmark

		# 11. Run experiment if this is not a no slow
		if [ "$exptype" != "noslowmaxthroughput" -a "$exptype" != "noslowminthroughput" -a "$exptype" != "noslowfollower" ]; then
			run_experiment
		fi

		run_benchmark

		# 13. cleanup
		if [ "$filesystem" == "disk" ]; then
			cleanup_disk
		elif [ "$filesystem" == "memory" ]; then
			cleanup_memory
		else
			echo "This option in filesystem is not supported.Exiting."
			exit 1
		fi
		
		# 14. Power off all the VMs
		stop_servers
	done
}

test_start cockroachdb
test_run

# Make sure either shutdown is executed after you run this script or uncomment the last line
# sudo shutdown -h now
