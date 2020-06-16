#!/bin/bash

set -ex

# Server specific configs
##########################
s1="10.128.15.193"
s2="10.128.0.14"
s3="10.128.0.15"

s1name="rethinkdb_first"
s2name="rethinkdb_second"
s3name="rethinkdb_third"
serverZone="us-central1-a"
###########################

if [ "$#" -ne 6 ]; then
    echo "Wrong number of parameters"
    echo "1st arg - number of iterations"
    echo "2nd arg - workload path"
    echo "3rd arg - seconds to run ycsb run"
    echo "4th arg - experiment to run(1,2,3,4,5)"
    echo "5th arg - host type(gcp/aws)"
    echo "6th arg - type of experiment(follower/leader/noslow)"
    exit 1
fi

iterations=$1
workload=$2
ycsbruntime=$3
expno=$4
host=$5
exptype=$6

# test_start is executed at the beginning
function test_start {
	name=$1
	
	echo "Running $exptype experiment $expno for $name"
	dirname="$name"_"$exptype"_results
	mkdir -p $dirname
}

# data_cleanup is called just after servers start
function data_cleanup {
	ssh -i ~/.ssh/id_rsa "$s1" "sh -c 'rm -rf /data1/*'"
	ssh -i ~/.ssh/id_rsa "$s2" "sh -c 'rm -rf /data1/*'"
	ssh -i ~/.ssh/id_rsa "$s3" "sh -c 'rm -rf /data1/*'"
}

# start_servers is used to boot the servers up
function start_servers {	
	if [ "$host" == "gcp" ]; then
		gcloud compute instances start "$s1name" "$s2name" "$s3name" --zone="$serverZone"
	elif [ "$host" == "aws" ]; then
		echo "Not implemented error"
		exit 1
	else
		echo "Not implemented error"
		exit 1
	fi
	sleep 60
}

# init is called to initialise the db servers
function init {

}

# start_db starts the database instances on each of the server
function start_db {
	ssh  -i ~/.ssh/id_rsa "$s1" "sh -c 'nohup taskset -ac 0 rethinkdb --directory /data1/rethinkdb_data1 --bind all --server-name rethinkdb_first > /dev/null 2>&1 &'" 
	ssh  -i ~/.ssh/id_rsa "$s2" "sh -c 'nohup taskset -ac 0 rethinkdb --directory /data1/rethinkdb_data2 --join 10.128.15.193:29015 --bind all --server-name rethinkdb_second > /dev/null 2>&1 &'"
	ssh  -i ~/.ssh/id_rsa "$s3" "sh -c 'nohup taskset -ac 0 rethinkdb --directory /data1/rethinkdb_data3 --join 10.128.15.193:29015 --bind all --server-name rethinkdb_third > /dev/null 2>&1 &'"
	sleep 30
}

# db_init initialises the database
function db_init {
	source venv/bin/activate ;  python initr.py > tablesinfo ; deactivate
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
	./bin/ycsb load rethinkdb -s -P workloads/workloada_more -p rethinkdb.host=10.128.15.193 -p rethinkdb.port=28015
}

# ycsb run exectues the given workload and waits for it to complete
function ycsb_run {
	./bin/ycsb run rethinkdb -s -P workloads/workloada_more -p maxexecutiontime=900 -p rethinkdb.host=$primaryip -p rethinkdb.port=28015 > "$dirname"/exp"$expno"_trial_"$i".txt
}

# cleanup is called at the end of the given trial of an experiment
function cleanup {
	source venv/bin/activate ;  python cleanup.py > tablesinfo ; deactivate
	ssh -i ~/.ssh/id_rsa "$s1" "sudo sh -c 'sudo rm -rf /data1/ ; sudo cgdelete cpu:db cpu:cpulow cpu:cpuhigh blkio:db ; pkill rethinkdb ; true'"
	ssh -i ~/.ssh/id_rsa "$s2" "sudo sh -c 'sudo rm -rf /data1/ ; sudo cgdelete cpu:db cpu:cpulow cpu:cpuhigh blkio:db ; pkill rethinkdb ; true'"
	ssh -i ~/.ssh/id_rsa "$s3" "sudo sh -c 'sudo rm -rf /data1/ ; sudo cgdelete cpu:db cpu:cpulow cpu:cpuhigh blkio:db ; pkill rethinkdb ; true'"
	# Remove the tc rule for exp 5
	if [ "$expno" == 5 -a "$exptype" != "noslow" ]; then
		ssh -i ~/.ssh/id_rsa "$slowdownip" "sudo sh -c 'sudo /sbin/tc qdisc del dev ens4 root ; true'"
	fi
	sleep 5
}

# stop_servers turns off the VM instances
function stop_servers {
	if [ "$host" == "gcp" ]; then
		gcloud compute instances stop "$s1name" "$s2name" "$s3name" --zone="$serverZone"
	elif [ "$host" == "aws" ]; then
		echo "Not implemented error"
		exit 1
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

		# 2. Cleanup first
		data_cleanup	

		# 3. Create data directories
		init

		# 4. SSH to all the machines and start db
		start_db

		# 5. Init
		db_init

		# 6. ycsb load
		ycsb_load

		# 7. Run experiment if this is not a no slow
		if [ "$exptype" != "noslow" ]; then
			run_experiment
		fi

		# 8. ycsb run
		ycsb_run

		# 9. cleanup
		cleanup
		
		# 10. Power off all the VMs
		stop_servers
	done
}

test_start rethinkdb
test_run

# Make sure either shutdown is executed after you run this script or uncomment the last line
# sudo shutdown -h now
