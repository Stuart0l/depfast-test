#!/bin/bash

date=$(date +"%Y%m%d%s")
exec > "$date"_experiment.log
exec 2>&1

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
	for key in "${!serverNameIPMap[@]}";
	do
		ssh -i ~/.ssh/id_rsa ${serverNameIPMap[$key]} "sh -c 'rm -rf /data/*'"
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

# start_follower_db starts the database instances on each of the server with locality config set. first server is set to house all the leaseholders.
function start_follower_db {
    cservers=$(join_by , ${servernames[@]})
    for (( r=0; r<$noOfServers;r++ ));
    do
        ssh  -i ~/.ssh/id_rsa ${serverips[$r]} "sh -c 'nohup taskset -ac 0 cockroach start --insecure --advertise-addr=${serverips[$r]} --join=$cservers --cache=4GiB --max-sql-memory=4GiB --store=/"$datadir"/node"$r"/ --pid-file /"$datadir"/pid --locality=datacenter="${serverdcnames[$r]}" > /dev/null 2>&1 &'"

    done
    sleep 20
}

# start_max_min_throughput_db starts cockroach instances without the locality config set
function start_max_min_throughput_db {
    cservers=$(join_by , ${!serverNameIPMap[@]})
    for key in "${!serverNameIPMap[@]}";
    do
        ssh  -i ~/.ssh/id_rsa ${serverNameIPMap[$key]} "sh -c 'nohup taskset -ac 0 cockroach start --insecure --advertise-addr=${serverNameIPMap[$key]} --join=$cservers --cache=4GiB --max-sql-memory=4GiB --store=/"$datadir"/node1/ --pid-file /"$datadir"/pid > /dev/null 2>&1 &'"
    done
	sleep 20
}

# db_init initialises the database
function db_init {
	cockroach init --insecure --host="$initserver":26257

	# Wait for startup
	sleep 45

	if [ "$exptype" == "follower" -o "$exptype" == "noslowfollower" ]; then
		dcname=${serverdcnames[0]}
		
		# Set leaseholder config for follower tests
		cockroach sql --execute="ALTER TABLE system.public.replication_stats CONFIGURE ZONE USING lease_preferences = '[[+datacenter=$dcname]]';

		ALTER  TABLE system.public.replication_constraint_stats CONFIGURE ZONE USING lease_preferences = '[[+datacenter=$dcname]]';

		ALTER  TABLE system.public.jobs CONFIGURE ZONE USING constraints= '{"+datacenter=$dcname": 1}', lease_preferences = '[[+datacenter=$dcname]]';

		ALTER RANGE system CONFIGURE ZONE USING constraints= '{"+datacenter=$dcname": 1}', lease_preferences = '[[+datacenter=$dcname]]';

		ALTER DATABASE system CONFIGURE ZONE USING constraints= '{"+datacenter=$dcname": 1}', lease_preferences = '[[+datacenter=$dcname]]';

		ALTER RANGE default CONFIGURE ZONE USING num_replicas = 3, lease_preferences = '[[+datacenter=$dcname]]';" --insecure --host="$initserver"

		# Create ycsb DB
		cockroach sql --execute="CREATE DATABASE ycsb;" --insecure --host="$initserver"

		cockroach sql --execute="ALTER database ycsb CONFIGURE ZONE USING constraints= '{"+datacenter=$dcname": 1}', lease_preferences = '[[+datacenter=$dcname]]', num_replicas = 3;" --insecure --host="$initserver"

	elif [[ "$exptype" =~ $tppattern ]]; then
		# Create ycsb DB
		cockroach sql --execute="CREATE DATABASE ycsb;" --insecure --host="$initserver"
	else
		# Pathological case
		# Create ycsb DB
		cockroach sql --execute="CREATE DATABASE ycsb;" --insecure --host="$initserver"
	fi

	# Create ycsb usertable
	cockroach sql --execute="
	CREATE TABLE ycsb.usertable (
		ycsb_key VARCHAR(255) NOT NULL,
		field0 STRING NULL,
		field1 STRING NULL,
		field2 STRING NULL,
		field3 STRING NULL,
		field4 STRING NULL,
		field5 STRING NULL,
		field6 STRING NULL,
		field7 STRING NULL,
		field8 STRING NULL,
		field9 STRING NULL,
		CONSTRAINT \"primary\" PRIMARY KEY (ycsb_key ASC),
		FAMILY fam_0_ycsb_key (ycsb_key),
		FAMILY fam_1_field0 (field0),
		FAMILY fam_2_field1 (field1),
		FAMILY fam_3_field2 (field2),
		FAMILY fam_4_field3 (field3),
		FAMILY fam_5_field4 (field4),
		FAMILY fam_6_field5 (field5),
		FAMILY fam_7_field6 (field6),
		FAMILY fam_8_field7 (field7),
		FAMILY fam_9_field8 (field8),
		FAMILY fam_10_field9 (field9)
	);" --insecure --host="$initserver"

	sleep 45s
}

# ycsb_load is used to run the ycsb load and wait until it completes.
function ycsb_load {
	# load on the first server
	./bin/ycsb load jdbc -s -P $workload -p db.driver=org.postgresql.Driver -p db.user=root -p db.passwd=root -p db.url=jdbc:postgresql://"$initserver":26257/ycsb?sslmode=disable -cp jdbc-binding/lib/postgresql-42.2.10.jar -threads 50

	# Check the leaseholders
	cockroach sql --execute="SELECT table_name,range_id,lease_holder FROM [show ranges from database system];SELECT table_name,range_id,lease_holder FROM [show ranges from database ycsb];" --insecure --host="$initserver"
}

# ycsb run exectues the given workload and waits for it to complete
function ycsb_run {
	# Run ycsb always at primary
	# For maxthroughput slowness, this is the node with max throughput
	# For minthroughput slowness, this is the node with min throughput
	# For follower slowness, we chose leader as first server, as it has the locality config set
	# WE should clear the memory:db cgroup for ycsb to complete as it keeps waiting for some threads to complete if the fail-slow is too aggressive
	exp6cleartime=$(($ycsbruntime+30))
	if [ "$expno" == 6 ]; then
		ssh -i ~/.ssh/id_rsa "$primaryip" "sudo sh -c 'sleep $exp6cleartime && sudo cgdelete memory:db'" > /dev/null 2>&1 & 
	fi

	ycsbserverip=$1
	ycsbrtime=$2
	# Server IPs for last server
	taskset -ac 0 bin/ycsb run jdbc -s -P $workload -p maxexecutiontime=$ycsbrtime -cp jdbc-binding/lib/postgresql-42.2.10.jar -p db.driver=org.postgresql.Driver -p db.user=root -p db.passwd=root -p db.url=jdbc:postgresql://"$ycsbserverip":26257/ycsb?sslmode=disable -threads $ycsbthreads > "$dirname"/exp"$expno"_trial_"$i".txt

	sleep 30s
	# Verify that all the range leaseholders are on Node 1.
	cockroach sql --execute="SELECT table_name,range_id,lease_holder FROM [show ranges from database system];SELECT table_name,range_id,lease_holder FROM [show ranges from database ycsb];" --insecure --host="$initserver"

	# Run node status
	cockroach node status --host="$initserver" --insecure
}

# cleanup_disk is called at the end of the given trial of an experiment
function cleanup_disk {
	cockroach sql --execute="drop database ycsb CASCADE;" --insecure --host="$initserver"
    for key in "${!serverNameIPMap[@]}";
    do
        cockroach quit --insecure --host="${serverNameIPMap[$key]}":26257
    done

    for key in "${!serverNameIPMap[@]}";
    do
        ssh -i ~/.ssh/id_rsa "${serverNameIPMap[$key]}" "sudo sh -c 'pkill cockroach ; sudo rm -rf /data/*; sudo rm -rf /data ; sudo umount $partitionName ; sudo rm -rf /data/ ; sudo cgdelete cpu:db cpu:cpulow cpu:cpuhigh blkio:db memory:db; true'"
    done

	# Remove the tc rule for exp 5
	if [ "$expno" == 5 -a "$exptype" != "noslowfollower" ]; then
		if [ "$exptype" != "noslowmaxthroughput" -a "$exptype" != "noslowminthroughput" ]; then
		  ssh -i ~/.ssh/id_rsa "$slowdownip" "sudo sh -c 'sudo /sbin/tc qdisc del dev "$nic" root ; true'"
		fi  
	fi  
	if [[  "$exptype" =~ $tppattern ]]; then
	    rm raft.json
	fi 
	sleep 5
}

function cleanup_memory {
	cockroach sql --execute="drop database ycsb CASCADE;" --insecure --host="$initserver"
    for key in "${!serverNameIPMap[@]}";
    do
        cockroach quit --insecure --host="${serverNameIPMap[$key]}":26257
    done

	 if [ "$swappiness" == "swapon" ] ; then
        for key in "${!serverNameIPMap[@]}";
        do
            ssh -i ~/.ssh/id_rsa "${serverNameIPMap[$key]}" "sudo sh -c 'pkill cockroach ; sudo swapoff -v /data/swapfile'"
        done
	fi

    for key in "${!serverNameIPMap[@]}";
    do
        ssh -i ~/.ssh/id_rsa "${serverNameIPMap[$key]}" "sudo sh -c 'pkill cockroach ; sudo rm -rf /data/* ; sudo rm -rf /data/ ; sudo cgdelete cpu:db cpu:cpulow cpu:cpuhigh blkio:db memory:db; true'"
    done
	if [ "$swappiness" == "swapon" ]; then
        for key in "${!serverNameIPMap[@]}";
        do
            ssh -i ~/.ssh/id_rsa "${serverNameIPMap[$key]}" "sudo sh -c 'sudo umount $partitionName'"
    done
	fi
	# Remove the tc rule for exp 5
	if [ "$expno" == 5 -a "$exptype" != "noslowfollower" ]; then
		if [ "$exptype" != "noslowmaxthroughput" -a "$exptype" != "noslowminthroughput" ]; then
		  ssh -i ~/.ssh/id_rsa "$slowdownip" "sudo sh -c 'sudo /sbin/tc qdisc del dev "$nic" root ; true'"
		fi  
	fi  
	if [[  "$exptype" =~ $tppattern ]]; then
	    rm raft.json
	fi 
	sleep 5
}

# stop_servers turns off the VM instances
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

# This is specific to cockroachdb as it has concept of ranges and hence needs
# different way to identify the node that has to be slowed-down.
function find_node_to_slowdown {
	if [  "$exptype" == "maxthroughput" -o "$exptype" == "noslowmaxthroughput" ]; then
		# Download raft stats
		wget http://"$initserver":8080/_status/raft -O raft.json
		# Identify the node that needs to be slowed down here
		# run the parser code to identify the node id of the MAX throughput node
		echo "Picking max throughput node to slowdown"
		nodeid=$(python3 throughputparser.py raft.json | grep -Eo 'maxnodeid=[0-9]' | cut -d'=' -f2-)
		echo $nodeid

		slowdownip=$(cockroach node status --host="$initserver":26257 --insecure --format tsv | awk '{print $1, $2 }' | grep "$nodeid " | grep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}')
		slowdownpid=$(ssh -i ~/.ssh/id_rsa "$slowdownip" "sh -c 'cat /"$datadir"/pid'")
		primaryip=$slowdownip
	elif [  "$exptype" == "minthroughput" -o "$exptype" == "noslowminthroughput" ]; then
		# Download raft stats
		wget http://"$initserver":8080/_status/raft -O raft.json
		# Identify the node that needs to be slowed down here
		# run the parser code to identify the node id of the MIN throughput node
		echo "Picking min throughput node to slowdown"
		nodeid=$(python3 throughputparser.py raft.json | grep -Eo 'minnodeid=[0-9]' | cut -d'=' -f2-)
		echo $nodeid

		slowdownip=$(cockroach node status --host="$initserver":26257 --insecure --format tsv | awk '{print $1, $2 }' | grep "$nodeid " | grep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}')
		slowdownpid=$(ssh -i ~/.ssh/id_rsa "$slowdownip" "sh -c 'cat /"$datadir"/pid'")
		primaryip=$slowdownip
	elif [  "$exptype" == "follower" -o "$exptype" == "noslowfollower" ]; then
		# Since locality is set on first server, that is the primary and rest are secondary
		# Primary ip is the first
		primaryip=${serverips[0]}
		secondaryip=${serverips[1]}
		primarypid=$(ssh -i ~/.ssh/id_rsa "$primaryip" "sh -c 'cat /"$datadir"/pid'")
		secondarypid=$(ssh -i ~/.ssh/id_rsa "$secondaryip" "sh -c 'cat /"$datadir"/pid'")
		# The follower node is slowed down
		slowdownpid=$secondarypid
		slowdownip=$secondaryip
	else
		echo "Nothing to slowdown"
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

		# 7. SSH to all the machines and start db
		if [ "$exptype" == "follower" -o "$exptype" == "noslowfollower" ]; then
			# With locality config set
			start_follower_db
		elif [ "$exptype" == "pathological" ]; then
			start_follower_db
		elif [[ "$exptype" =~ $tppattern ]]; then
			# Without locality config set
			start_max_min_throughput_db
		else
			echo ""
		fi

		# 8. Init
		db_init

		# 9. ycsb load
		# YCSB load on serverips[0]
		ycsb_load

		# 10. Find out node to slowdown
		#find_node_to_slowdown

		# 11. Run experiment if this is not a no slow
		#if [ "$exptype" != "noslowmaxthroughput" -a "$exptype" != "noslowminthroughput" -a "$exptype" != "noslowfollower" ]; then
		#	run_experiment
		#fi

		# 12. ycsb run
		# YCSB run on serverips[2]
		ycsb_run ${serverips[2]} $ycsbruntime

		# Add 200 ms latency to all nodes
		# This is required without high latency, follow the workload doesn’t kicks in.
		# https://www.cockroachlabs.com/docs/stable/demo-follow-the-workload.html#step-3-simulate-network-latency
	    	for (( z=0; z<$noOfServers;z++ ));
	    	do
			ssh -i ~/.ssh/id_rsa "${serverips[$z]}" "sudo sh -c 'sudo /sbin/tc qdisc add dev eth0 root netem delay 200ms'"
	    	done

		# Add CPU slowness to node 2
		slowdownip=${serverips[1]}
		slowdownpid=$(ssh -i ~/.ssh/id_rsa "$slowdownip" "sh -c 'cat /"$datadir"/pid'")
		ssh -i ~/.ssh/id_rsa "$slowdownip" "sudo sh -c 'sudo mkdir /sys/fs/cgroup/cpu/db'"
		ssh -i ~/.ssh/id_rsa "$slowdownip" "sudo sh -c 'sudo echo 500000 > /sys/fs/cgroup/cpu/db/cpu.cfs_quota_us'"
		ssh -i ~/.ssh/id_rsa "$slowdownip" "sudo sh -c 'sudo echo 1000000 > /sys/fs/cgroup/cpu/db/cpu.cfs_period_us'"
		ssh -i ~/.ssh/id_rsa "$slowdownip" "sudo sh -c 'sudo echo $slowdownpid > /sys/fs/cgroup/cpu/db/cgroup.procs'"

		# Run ycsb at node 2 for 20 mins now
		ycsb_run ${serverips[1]} 1500

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
