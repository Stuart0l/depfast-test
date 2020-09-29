#!/bin/bash

#date=$(date +"%Y%m%d%s")
#exec > "$date"_experiment.log
#exec 2>&1

set -ex

# Server specific configs
##########################
s1="10.0.0.14"
s2="10.0.0.15"
s3="10.0.0.16"

s1name="mongodbssd-1"
s2name="mongodbssd-2"
s3name="mongodbssd-3"
serverZone="us-central1-a"
###########################

if [ "$#" -ne 9 ]; then
    echo "Wrong number of parameters"
    echo "1st arg - number of iterations"
    echo "2nd arg - workload path"
    echo "3rd arg - seconds to run ycsb run"
    echo "4th arg - experiment to run(1, 2, 3 only for hdd, 4 only for hdd, 5, 6 only for swapon+mem)"
    echo "5th arg - host type(gcp/azure)"
    echo "6th arg - type of experiment(follower/leader/noslow)"
    echo "7th arg - turn on swap (swapon/swapoff) [swapon only for exp6+mem] "
    echo "8th arg - in disk or in memory (hdd/mem)"
	echo "9th arg - threads for ycsb run(for saturation exp)"
    exit 1
fi

iterations=$1
workload=$2
ycsbruntime=$3
expno=$4
host=$5
exptype=$6
swapness=$7
ondisk=$8
ycsbthreads=$9

# test_start is executed at the beginning
function test_start {
  name=$1
  echo "Running $exptype experiment $expno $swapness $ondisk for $name"
  dirname="$name"_"$exptype"_"$swapness"_"$ondisk"_"$ycsbthreads"_results
  mkdir -p $dirname
}

# data_cleanup is called just after servers start
function data_cleanup {
  if [ "$ondisk" == "mem" ] ; then
    ssh -i ~/.ssh/id_rsa "$s1" "sh -c 'sudo rm -rf /ramdisk/mongodb-data'"
    ssh -i ~/.ssh/id_rsa "$s2" "sh -c 'sudo rm -rf /ramdisk/mongodb-data'"
    ssh -i ~/.ssh/id_rsa "$s3" "sh -c 'sudo rm -rf /ramdisk/mongodb-data'"
  else
    ssh -i ~/.ssh/id_rsa "$s1" "sh -c 'sudo rm -rf /data1/mongodb-data'"
    ssh -i ~/.ssh/id_rsa "$s2" "sh -c 'sudo rm -rf /data1/mongodb-data'"
    ssh -i ~/.ssh/id_rsa "$s3" "sh -c 'sudo rm -rf /data1/mongodb-data'"
  fi
}

function start_servers {
  if [ "$host" == "gcp" ]; then
    gcloud compute instances start "$s1name" "$s2name" "$s3name" --zone="$serverZone"
  elif [ "$host" == "azure" ]; then
    az vm start --resource-group DepFast3 --subscription "Last Chance" --name "$s1name"
    az vm start --resource-group DepFast3 --subscription "Last Chance" --name "$s2name"
    az vm start --resource-group DepFast3 --subscription "Last Chance" --name "$s3name"
  else
    echo "Not implemented error"
    exit 1
  fi
  sleep 30
}

# init is called to initialise the db servers
function init {
#ssh -i ~/.ssh/id_rsa "$s1" "sudo sh -c 'sudo umount /dev/sdc1 ; sudo mkdir -p /data1 ; sudo mkfs.ext4 /dev/sdc1 -F ; sudo mount -t ext4 /dev/sdc1 /data1 -o defaults,nodelalloc,noatime ; sudo chmod o+w /data1/ ; mkdir /data1/mongodb-data ; sudo chmod o+w /data1/mongodb-data'"
#ssh -i ~/.ssh/id_rsa "$s2" "sudo sh -c 'sudo umount /dev/sdc1 ; sudo mkdir -p /data1 ; sudo mkfs.ext4 /dev/sdc1 -F ; sudo mount -t ext4 /dev/sdc1 /data1 -o defaults,nodelalloc,noatime ; sudo chmod o+w /data1/ ; mkdir /data1/mongodb-data ; sudo chmod o+w /data1/mongodb-data'"
#ssh -i ~/.ssh/id_rsa "$s3" "sudo sh -c 'sudo umount /dev/sdc1 ; sudo mkdir -p /data1 ; sudo mkfs.ext4 /dev/sdc1 -F ; sudo mount -t ext4 /dev/sdc1 /data1 -o defaults,nodelalloc,noatime ; sudo chmod o+w /data1/ ; mkdir /data1/mongodb-data ; sudo chmod o+w /data1/mongodb-data'"
  ssh -i ~/.ssh/id_rsa "$s1" "sudo sh -c 'sudo umount /dev/sdc1 ; sudo mkdir -p /data1 ; sudo mkfs.xfs /dev/sdc1 -f ; sudo mount -t xfs /dev/sdc1 /data1 ; sudo mount -t xfs /dev/sdc1 /data1 -o remount,noatime ; sudo chmod o+w /data1 ; mkdir /data1/mongodb-data ; sudo chmod o+w /data1/mongodb-data'"
  ssh -i ~/.ssh/id_rsa "$s2" "sudo sh -c 'sudo umount /dev/sdc1 ; sudo mkdir -p /data1 ; sudo mkfs.xfs /dev/sdc1 -f ; sudo mount -t xfs /dev/sdc1 /data1 ; sudo mount -t xfs /dev/sdc1 /data1 -o remount,noatime ; sudo chmod o+w /data1 ; mkdir /data1/mongodb-data ; sudo chmod o+w /data1/mongodb-data'"
  ssh -i ~/.ssh/id_rsa "$s3" "sudo sh -c 'sudo umount /dev/sdc1 ; sudo mkdir -p /data1 ; sudo mkfs.xfs /dev/sdc1 -f ; sudo mount -t xfs /dev/sdc1 /data1 ; sudo mount -t xfs /dev/sdc1 /data1 -o remount,noatime ; sudo chmod o+w /data1 ; mkdir /data1/mongodb-data ; sudo chmod o+w /data1/mongodb-data'"

  if [ "$swapness" == "swapoff" ] ; then
    ssh -i ~/.ssh/id_rsa "$s1" "sudo sh -c 'sudo sysctl vm.swappiness=0 ; sudo swapoff -a && swapon -a'"
    ssh -i ~/.ssh/id_rsa "$s2" "sudo sh -c 'sudo sysctl vm.swappiness=0 ; sudo swapoff -a && swapon -a'"
    ssh -i ~/.ssh/id_rsa "$s3" "sudo sh -c 'sudo sysctl vm.swappiness=0 ; sudo swapoff -a && swapon -a'"
  else
    ssh -i ~/.ssh/id_rsa "$s1" "sudo sh -c 'sudo dd if=/dev/zero of=/data1/swapfile bs=1024 count=25165824 ; sudo chmod 600 /data1/swapfile ; sudo mkswap /data1/swapfile'"  # 24GB
    ssh -i ~/.ssh/id_rsa "$s1" "sudo sh -c 'sudo sysctl vm.swappiness=60 ; sudo swapoff -a && swapon -a ; sudo swapon /data1/swapfile'"
    ssh -i ~/.ssh/id_rsa "$s2" "sudo sh -c 'sudo dd if=/dev/zero of=/data1/swapfile bs=1024 count=25165824 ; sudo chmod 600 /data1/swapfile ; sudo mkswap /data1/swapfile'"  # 24GB
    ssh -i ~/.ssh/id_rsa "$s2" "sudo sh -c 'sudo sysctl vm.swappiness=60 ; sudo swapoff -a && swapon -a ; sudo swapon /data1/swapfile'"
    ssh -i ~/.ssh/id_rsa "$s3" "sudo sh -c 'sudo dd if=/dev/zero of=/data1/swapfile bs=1024 count=25165824 ; sudo chmod 600 /data1/swapfile ; sudo mkswap /data1/swapfile'"  # 24GB
    ssh -i ~/.ssh/id_rsa "$s3" "sudo sh -c 'sudo sysctl vm.swappiness=60 ; sudo swapoff -a && swapon -a ; sudo swapon /data1/swapfile'"
  fi

  if [ "$ondisk" == "mem" ] ; then
    ssh -i ~/.ssh/id_rsa "$s1" "sudo sh -c 'sudo mkdir -p /ramdisk ; sudo mount -t tmpfs -o rw,size=8G tmpfs /ramdisk/ ; sudo chmod o+w /ramdisk/ ; mkdir /ramdisk/mongodb-data ; sudo chmod o+w /ramdisk/mongodb-data'"
    ssh -i ~/.ssh/id_rsa "$s2" "sudo sh -c 'sudo mkdir -p /ramdisk ; sudo mount -t tmpfs -o rw,size=8G tmpfs /ramdisk/ ; sudo chmod o+w /ramdisk/ ; mkdir /ramdisk/mongodb-data ; sudo chmod o+w /ramdisk/mongodb-data'"
    ssh -i ~/.ssh/id_rsa "$s3" "sudo sh -c 'sudo mkdir -p /ramdisk ; sudo mount -t tmpfs -o rw,size=8G tmpfs /ramdisk/ ; sudo chmod o+w /ramdisk/ ; mkdir /ramdisk/mongodb-data ; sudo chmod o+w /ramdisk/mongodb-data'"
  fi
}

# start_db starts the database instances on each of the server
function start_db {
  if [ "$ondisk" == "mem" ] ; then
    ssh  -i ~/.ssh/id_rsa "$s1" "sh -c 'numactl --interleave=all taskset -ac 0 /home/tidb/mongodb/bin/mongod --replSet rs0 --bind_ip localhost,"$s1name" --fork --logpath /tmp/mongod.log --dbpath /ramdisk/mongodb-data'"
    ssh  -i ~/.ssh/id_rsa "$s2" "sh -c 'numactl --interleave=all taskset -ac 0 /home/tidb/mongodb/bin/mongod --replSet rs0 --bind_ip localhost,"$s2name" --fork --logpath /tmp/mongod.log --dbpath /ramdisk/mongodb-data'"
    ssh  -i ~/.ssh/id_rsa "$s3" "sh -c 'numactl --interleave=all taskset -ac 0 /home/tidb/mongodb/bin/mongod --replSet rs0 --bind_ip localhost,"$s3name" --fork --logpath /tmp/mongod.log --dbpath /ramdisk/mongodb-data'"
  else
    ssh  -i ~/.ssh/id_rsa "$s1" "sh -c 'numactl --interleave=all taskset -ac 0 /home/tidb/mongodb/bin/mongod --replSet rs0 --bind_ip localhost,"$s1name" --fork --logpath /tmp/mongod.log --dbpath /data1/mongodb-data'"
    ssh  -i ~/.ssh/id_rsa "$s2" "sh -c 'numactl --interleave=all taskset -ac 0 /home/tidb/mongodb/bin/mongod --replSet rs0 --bind_ip localhost,"$s2name" --fork --logpath /tmp/mongod.log --dbpath /data1/mongodb-data'"
    ssh  -i ~/.ssh/id_rsa "$s3" "sh -c 'numactl --interleave=all taskset -ac 0 /home/tidb/mongodb/bin/mongod --replSet rs0 --bind_ip localhost,"$s3name" --fork --logpath /tmp/mongod.log --dbpath /data1/mongodb-data'"
  fi
  sleep 30
}

# db_init initialises the database
function db_init {
  /home/tidb/mongodb/bin/mongo --host "$s1name" < init_script_hdd.js

  # Wait for startup
  sleep 60

  /home/tidb/mongodb/bin/mongo --host "$s1name" < fetchprimary.js  | tail -n +5 | head -n -1  > result.json
  cat result.json

  primaryip=$(python parse_hdd.py | grep primary | cut -d" " -f2-)
  secondaryip=$(python parse_hdd.py | grep secondary | cut -d" " -f2-)

  primarypid=$(ssh -i ~/.ssh/id_rsa "$primaryip" "sh -c 'pgrep mongo'")
  echo $primarypid

  secondarypid=$(ssh -i ~/.ssh/id_rsa "$secondaryip" "sh -c 'pgrep mongo'")
  echo $secondarypid

  if [ "$exptype" == "follower" ]; then
    slowdownpid=$secondarypid
    slowdownip=$secondaryip
    scp clear_dd_file.sh tidb@"$slowdownip":~/
  elif [ "$exptype" == "leader" ]; then
    slowdownpid=$primarypid
    slowdownip=$primaryip
    scp clear_dd_file.sh tidb@"$slowdownip":~/
  else
    # Nothing to do
    echo ""
  fi

  # Disable chaining allowed
  /home/tidb/mongodb/bin/mongo --host $primaryip --eval "cfg = rs.config(); cfg.settings.chainingAllowed = false; rs.reconfig(cfg);"
  #/home/tidb/mongodb/bin/mongo --host $s1 --eval "db.adminCommand( { replSetSyncFrom: '$primaryip' })"
  /home/tidb/mongodb/bin/mongo --host mongodbssd-2 --eval "db.adminCommand( { replSetSyncFrom: 'mongodbssd-1:27017' })"
  /home/tidb/mongodb/bin/mongo --host mongodbssd-3 --eval "db.adminCommand( { replSetSyncFrom: 'mongodbssd-1:27017' })"

  # Set WriteConcern==majority    in order to make it consistent between all DBs
  /home/tidb/mongodb/bin/mongo --host $primaryip --eval "cfg = rs.config(); cfg.settings.getLastErrorDefaults = { j:true, w:'majority', wtimeout:10000 }; rs.reconfig(cfg);"
}

# ycsb_load is used to run the ycsb load and wait until it completes.
function ycsb_load {
  cd /home/tidb/ycsb-0.17.0/bin
  /home/tidb/ycsb-0.17.0/bin/ycsb load mongodb -s -P /home/tidb/gray-testing/scripts/mongodb/$workload  -threads 32 -p mongodb.url=mongodb://$primaryip:27017/ycsb?w=majority&readConcernLevel=majority ; wait $!
  cd /home/tidb/gray-testing/scripts/mongodb
}

# ycsb run exectues the given workload and waits for it to complete
function ycsb_run {
  cd /home/tidb/ycsb-0.17.0/bin
  /home/tidb/ycsb-0.17.0/bin/ycsb run mongodb -s -P /home/tidb/gray-testing/scripts/mongodb/$workload -threads $ycsbthreads  -p maxexecutiontime=$ycsbruntime -p mongodb.url="mongodb://$primaryip:27017/ycsb?w=majority&readConcernLevel=majority" > /home/tidb/gray-testing/scripts/mongodb/"$dirname"/exp"$expno"_trial_"$i".txt ; wait $!
  #  -threads 32  for saturation
  cd /home/tidb/gray-testing/scripts/mongodb
}

# cleanup is called at the end of the given trial of an experiment
function mongo_cleanup {
  /home/tidb/mongodb/bin/mongo --host "$primaryip" < cleanup_script.js
  /home/tidb/mongodb/bin/mongo --host "$primaryip" --eval "db.getCollectionNames().forEach(function(n){db[n].remove()});"
  rm result.json
  sleep 5
}

function node_cleanup {
#  ssh -i ~/.ssh/id_rsa "$s1" "sudo sh -c 'rm -rf /data/db ; sudo umount /dev/sdb ; sudo rm -rf /data/ ; sudo cgdelete cpu:db cpu:cpulow cpu:cpuhigh blkio:db ; pkill mongod ; true'"
#  ssh -i ~/.ssh/id_rsa "$s2" "sudo sh -c 'rm -rf /data/db ; sudo umount /dev/sdb ; sudo rm -rf /data/ ; sudo cgdelete cpu:db cpu:cpulow cpu:cpuhigh blkio:db ; pkill mongod ; true'"
#  ssh -i ~/.ssh/id_rsa "$s3" "sudo sh -c 'rm -rf /data/db ; sudo umount /dev/sdb ; sudo rm -rf /data/ ; sudo cgdelete cpu:db cpu:cpulow cpu:cpuhigh blkio:db ; pkill mongod ; true'"
#  # Remove the tc rule for exp 5
#  if [ "$expno" == 5 -a "$exptype" != "noslow" ]; then
#    ssh -i ~/.ssh/id_rsa "$slowdownip" "sudo sh -c 'sudo /sbin/tc qdisc del dev eth0 root ; true'"
#  fi
  ssh -i ~/.ssh/id_rsa tidb@"$s1" "sudo cgdelete cpu:db cpu:cpulow cpu:cpuhigh blkio:db memory:db ; true"
  ssh -i ~/.ssh/id_rsa tidb@"$s1" "sudo /sbin/tc qdisc del dev eth0 root ; true"
  sleep 5
  ssh -i ~/.ssh/id_rsa tidb@"$s2" "sudo cgdelete cpu:db cpu:cpulow cpu:cpuhigh blkio:db memory:db ; true"
  ssh -i ~/.ssh/id_rsa tidb@"$s2" "sudo /sbin/tc qdisc del dev eth0 root ; true"
  sleep 5
  ssh -i ~/.ssh/id_rsa tidb@"$s3" "sudo cgdelete cpu:db cpu:cpulow cpu:cpuhigh blkio:db memory:db ; true"
  ssh -i ~/.ssh/id_rsa tidb@"$s3" "sudo /sbin/tc qdisc del dev eth0 root ; true"
  sleep 5
}

# stop_servers turns off the VM instances
function stop_servers {
  if [ "$host" == "gcp" ]; then
    gcloud compute instances stop "$s1name" "$s2name" "$s3name" --zone="$serverZone"
  elif [ "$host" == "azure" ]; then
    az vm deallocate --resource-group DepFast3 --subscription "Last Chance" --name "$s1name"
    az vm deallocate --resource-group DepFast3 --subscription "Last Chance" --name "$s2name"
    az vm deallocate --resource-group DepFast3 --subscription "Last Chance" --name "$s3name"
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
    #data_cleanup  
    node_cleanup

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
    mongo_cleanup
    node_cleanup
    #data_cleanup

    # 10. Power off all the VMs
    stop_servers
  done
}

test_start mongodb
test_run

# Make sure either shutdown is executed after you run this script or uncomment the last line
# sudo shutdown -h now
