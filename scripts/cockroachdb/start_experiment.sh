#!/bin/bash

set -ex

# Server specific configs
##########################
s1="10.128.0.36"
s2="10.128.0.37"
s3="10.128.0.38"

s1name="ritz-cockroachdb-1"
s2name="ritz-cockroachdb-2"
s3name="ritz-cockroachdb-3"
serverZone="us-central1-a"
###########################

if [ "$#" -ne 6 ]; then
    echo "Wrong number of parameters"
    echo "1st arg - number of iterations"
    echo "2nd arg - workload path"
    echo "3rd arg - seconds to run ycsb run"
    echo "4th arg - experiment to run(1,2,3,4,5)"
    echo "5th arg - host type(gcp/azure)"
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
	ssh -i ~/.ssh/id_rsa "$s1" "sh -c 'rm -rf /data/*'"
	ssh -i ~/.ssh/id_rsa "$s2" "sh -c 'rm -rf /data/*'"
	ssh -i ~/.ssh/id_rsa "$s3" "sh -c 'rm -rf /data/*'"
}

# start_servers is used to boot the servers up
function start_servers {	
	if [ "$host" == "gcp" ]; then
		gcloud compute instances start "$s1name" "$s2name" "$s3name" --zone="$serverZone"
	elif [ "$host" == "azure" ]; then
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
	ssh -i ~/.ssh/id_rsa "$s1" "sudo sh -c 'sudo mkdir -p /data ; sudo mkfs.xfs /dev/sdb -f ; sudo mount -t xfs /dev/sdb /data ; sudo mount -t xfs /dev/sdb /data -o remount,noatime ; sudo chmod o+w /data'"
	ssh -i ~/.ssh/id_rsa "$s2" "sudo sh -c 'sudo mkdir -p /data ; sudo mkfs.xfs /dev/sdb -f ; sudo mount -t xfs /dev/sdb /data ; sudo mount -t xfs /dev/sdb /data -o remount,noatime ; sudo chmod o+w /data'"
	ssh -i ~/.ssh/id_rsa "$s3" "sudo sh -c 'sudo mkdir -p /data ; sudo mkfs.xfs /dev/sdb -f ; sudo mount -t xfs /dev/sdb /data ; sudo mount -t xfs /dev/sdb /data -o remount,noatime ; sudo chmod o+w /data'"
}

# start_db starts the database instances on each of the server
function start_follower_db {
	ssh  -i ~/.ssh/id_rsa "$s1" "sh -c 'nohup taskset -ac 0 cockroach start --insecure --advertise-addr="$s1" --join="$s1","$s2","$s3" --cache=4GiB --max-sql-memory=4GiB --store=/data/node1/ --pid-file /data/pid --locality=datacenter=us-1 > /dev/null 2>&1 &'"
	ssh  -i ~/.ssh/id_rsa "$s2" "sh -c 'nohup taskset -ac 0 cockroach start --insecure --advertise-addr="$s2" --join="$s1","$s2","$s3" --cache=4GiB --max-sql-memory=4GiB --store=/data/node1/ --pid-file /data/pid --locality=datacenter=us-2 > /dev/null 2>&1 &'"
	ssh  -i ~/.ssh/id_rsa "$s3" "sh -c 'nohup taskset -ac 0 cockroach start --insecure --advertise-addr="$s3" --join="$s1","$s2","$s3" --cache=4GiB --max-sql-memory=4GiB --store=/data/node1/ --pid-file /data/pid --locality=datacenter=us-3 > /dev/null 2>&1 &'"
	sleep 30
}

function start_leader_db {
	ssh  -i ~/.ssh/id_rsa "$s1" "sh -c 'nohup taskset -ac 0 cockroach start --insecure --advertise-addr="$s1" --join="$s1","$s2","$s3" --cache=4GiB --max-sql-memory=4GiB --store=/data/node1/ --pid-file /data/pid > /dev/null 2>&1 &'"
	ssh  -i ~/.ssh/id_rsa "$s2" "sh -c 'nohup taskset -ac 0 cockroach start --insecure --advertise-addr="$s2" --join="$s1","$s2","$s3" --cache=4GiB --max-sql-memory=4GiB --store=/data/node1/ --pid-file /data/pid > /dev/null 2>&1 &'"
	ssh  -i ~/.ssh/id_rsa "$s3" "sh -c 'nohup taskset -ac 0 cockroach start --insecure --advertise-addr="$s3" --join="$s1","$s2","$s3" --cache=4GiB --max-sql-memory=4GiB --store=/data/node1/ --pid-file /data/pid > /dev/null 2>&1 &'"
	sleep 30
}

# db_init initialises the database
function db_init {
	cockroach init --insecure --host="$s1":26257

	# Wait for startup
	sleep 60

	primaryip=$s1
	secondaryip=$s2
	primarypid=$(ssh -i ~/.ssh/id_rsa "$s1" "sh -c 'cat /data/pid'")
	secondarypid=$(ssh -i ~/.ssh/id_rsa "$s2" "sh -c 'cat /data/pid'")

	# Create ycsb DB
	cockroach sql --execute="CREATE DATABASE ycsb;" --insecure --host="$s1"

	if [ "$exptype" == "follower" ]; then
		slowdownpid=$secondarypid
		slowdownip=$secondaryip	

		# Set leaseholder config for follower tests
		cockroach sql --execute="ALTER TABLE system.public.replication_stats CONFIGURE ZONE USING lease_preferences = '[[+datacenter=us-1]]';

		ALTER  TABLE system.public.replication_constraint_stats CONFIGURE ZONE USING lease_preferences = '[[+datacenter=us-1]]';

		ALTER  TABLE system.public.jobs CONFIGURE ZONE USING constraints= '{"+datacenter=us-1": 1}', lease_preferences = '[[+datacenter=us-1]]';

		ALTER RANGE system CONFIGURE ZONE USING constraints= '{"+datacenter=us-1": 1}', lease_preferences = '[[+datacenter=us-1]]';

		ALTER DATABASE system CONFIGURE ZONE USING constraints= '{"+datacenter=us-1": 1}', lease_preferences = '[[+datacenter=us-1]]';

		ALTER RANGE default CONFIGURE ZONE USING num_replicas = 3, lease_preferences = '[[+datacenter=us-1]]';" --insecure --host="$s1"

		cockroach sql --execute="ALTER database ycsb CONFIGURE ZONE USING constraints= '{"+datacenter=us-1": 1}', lease_preferences = '[[+datacenter=us-1]]', num_replicas = 3;" --insecure --host="$s1"

	elif [ "$exptype" == "leader" ]; then
		slowdownpid=$primarypid
		slowdownip=$primaryip
	else
		# Nothing to do
		echo ""
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
	);" --insecure --host="$s1"
}

# ycsb_load is used to run the ycsb load and wait until it completes.
function ycsb_load {
	./bin/ycsb load jdbc -s -P $workload -p db.driver=org.postgresql.Driver -p db.user=root -p db.passwd=root -p db.url=jdbc:postgresql://"$s1":26257/ycsb?sslmode=disable -cp jdbc-binding/lib/postgresql-42.2.10.jar

	# Check the leaseholders
	cockroach sql --execute="SELECT table_name,range_id,lease_holder FROM [show ranges from database system];SELECT table_name,range_id,lease_holder FROM [show ranges from database ycsb];" --insecure --host="$s1"
}

# ycsb run exectues the given workload and waits for it to complete
function ycsb_run {
	taskset -ac 0 bin/ycsb run jdbc -s -P $workload -p maxexecutiontime=$ycsbruntime -cp jdbc-binding/lib/postgresql-42.2.10.jar -p db.driver=org.postgresql.Driver -p db.user=root -p db.passwd=root -p db.url=jdbc:postgresql://"$s1":26257/ycsb?sslmode=disable

	# Verify that all the range leaseholders are on Node 1.
	cockroach sql --execute="SHOW RANGES FROM DATABASE ycsb;SHOW RANGES FROM DATABASE system;" --insecure --host="$s1"
}

# cleanup is called at the end of the given trial of an experiment
function cleanup {
	cockroach sql --execute="drop database ycsb CASCADE;" --insecure --host="$s1"
	cockroach quit --insecure --host="$s1":26257
	cockroach quit --insecure --host="$s2":26257
	cockroach quit --insecure --host="$s3":26257

	ssh -i ~/.ssh/id_rsa "$s1" "sudo sh -c 'sudo rm -rf /data/*; sudo rm -rf /data ; sudo umount /dev/sdb ; sudo rm -rf /data/ ; sudo cgdelete cpu:db cpu:cpulow cpu:cpuhigh blkio:db ; pkill cockroach  ; true'"
	ssh -i ~/.ssh/id_rsa "$s2" "sudo sh -c 'sudo rm -rf /data/* ; sudo rm -rf /data ; sudo umount /dev/sdb ; sudo rm -rf /data/ ; sudo cgdelete cpu:db cpu:cpulow cpu:cpuhigh blkio:db ; pkill cockroach ; true'"
	ssh -i ~/.ssh/id_rsa "$s3" "sudo sh -c 'sudo rm -rf /data/* ; sudo rm -rf /data ; sudo umount /dev/sdb ; sudo rm -rf /data/ ; sudo cgdelete cpu:db cpu:cpulow cpu:cpuhigh blkio:db ; pkill cockroach ; true'"
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
	elif [ "$host" == "azure" ]; then
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
		if [ "$exptype" == "follower" ]; then
			start_follower_db
		else
			start_leader_db
		fi

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

test_start cockroachdb
test_run

# Make sure either shutdown is executed after you run this script or uncomment the last line
# sudo shutdown -h now
