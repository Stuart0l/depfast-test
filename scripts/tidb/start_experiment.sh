#!/bin/bash

set -ex

# Server specific configs
##########################
pd="10.0.0.5"
s1="10.0.0.6"
s2="10.0.0.7"
s3="10.0.0.8"

pdname="tidb_pd"
s1name="tikv1"
s2name="tikv2"
s3name="tikv3"
serverZone="us-central1-a"
###########################

if [ "$#" -ne 6 ]; then
    echo "Wrong number of parameters"
    echo "1st arg - number of iterations"
    echo "2nd arg - workload path"
    echo "3rd arg - seconds to run ycsb run"
    echo "4th arg - experiment to run(1,2,3,4,5)"
    echo "5th arg - host type(gcp/aws)"
    echo "6th arg - type of experiment(follower/leader/noslow1/noslow2)"
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
  ssh -i ~/.ssh/id_rsa tidb@"$pd" "./.tiup/bin/tiup cluster destroy mytidb -y"
}

# start_servers is used to boot the servers up
function start_servers {  
  if [ "$host" == "gcp" ]; then
    gcloud compute instances start "$s1name" "$s2name" "$s3name" --zone="$serverZone"
  elif [ "$host" == "azure" ]; then
    az vm start --resource-group DepFast --name "$s1name"
    az vm start --resource-group DepFast --name "$s2name"
    az vm start --resource-group DepFast --name "$s3name"
  else
    echo "Not implemented error"
    exit 1
  fi
  sleep 60
}

# init is called to initialise the db servers
function init {
#  ssh -i ~/.ssh/id_rsa "$s1" "sudo sh -c 'sudo umount /dev/sdb1 ; sudo mkdir -p /data1 ; sudo mkfs.ext4 /dev/sdb1 -F ; sudo mount -t ext4 /dev/sdb1 /data1 -o defaults,nodelalloc,noatime ; sudo chmod o+w /data1/'"
#  ssh -i ~/.ssh/id_rsa "$s2" "sudo sh -c 'sudo umount /dev/sdb1 ; sudo mkdir -p /data1 ; sudo mkfs.ext4 /dev/sdb1 -F ; sudo mount -t ext4 /dev/sdb1 /data1 -o defaults,nodelalloc,noatime ; sudo chmod o+w /data1/'"
#  ssh -i ~/.ssh/id_rsa "$s3" "sudo sh -c 'sudo umount /dev/sdb1 ; sudo mkdir -p /data1 ; sudo mkfs.ext4 /dev/sdb1 -F ; sudo mount -t ext4 /dev/sdb1 /data1 -o defaults,nodelalloc,noatime ; sudo chmod o+w /data1/'"

  ssh -i ~/.ssh/id_rsa "$s1" "sudo sh -c 'sudo echo "vm.swappiness = 0">> /etc/sysctl.conf ; sudo swapoff -a && swapon -a ; sudo sysctl -p'"
  ssh -i ~/.ssh/id_rsa "$s2" "sudo sh -c 'sudo echo "vm.swappiness = 0">> /etc/sysctl.conf ; sudo swapoff -a && swapon -a ; sudo sysctl -p'"
  ssh -i ~/.ssh/id_rsa "$s3" "sudo sh -c 'sudo echo "vm.swappiness = 0">> /etc/sysctl.conf ; sudo swapoff -a && swapon -a ; sudo sysctl -p'"

  ssh -i ~/.ssh/id_rsa "$s1" "sudo sh -c 'sudo mkdir -p /ramdisk ; sudo mount -t tmpfs -o rw,size=8G tmpfs /ramdisk/ ; sudo chmod o+w /ramdisk/'"
  ssh -i ~/.ssh/id_rsa "$s2" "sudo sh -c 'sudo mkdir -p /ramdisk ; sudo mount -t tmpfs -o rw,size=8G tmpfs /ramdisk/ ; sudo chmod o+w /ramdisk/'"
  ssh -i ~/.ssh/id_rsa "$s3" "sudo sh -c 'sudo mkdir -p /ramdisk ; sudo mount -t tmpfs -o rw,size=8G tmpfs /ramdisk/ ; sudo chmod o+w /ramdisk/'"
}

# start_db starts the database instances on each of the server
function start_db {
  if [ "$exptype" == "follower" ] || [ "$exptype" == "noslow2" ] ; then
    ssh -i ~/.ssh/id_rsa tidb@"$pd" "./.tiup/bin/tiup cluster deploy mytidb v4.0.0 ./tidb_restrict.yaml --user tidb -y"
  else
    ssh -i ~/.ssh/id_rsa tidb@"$pd" "./.tiup/bin/tiup cluster deploy mytidb v4.0.0 ./tidb.yaml --user tidb -y"
  fi
  ssh -i ~/.ssh/id_rsa tidb@"$s1" "sudo sed -i 's#bin/tikv-server#taskset -ac 0 bin/tikv-server#g' /ramdisk/tidb-deploy/tikv-20160/scripts/run_tikv.sh "
  ssh -i ~/.ssh/id_rsa tidb@"$s2" "sudo sed -i 's#bin/tikv-server#taskset -ac 0 bin/tikv-server#g' /ramdisk/tidb-deploy/tikv-20160/scripts/run_tikv.sh "
  ssh -i ~/.ssh/id_rsa tidb@"$s3" "sudo sed -i 's#bin/tikv-server#taskset -ac 0 bin/tikv-server#g' /ramdisk/tidb-deploy/tikv-20160/scripts/run_tikv.sh "
  ssh -i ~/.ssh/id_rsa tidb@"$pd" "./.tiup/bin/tiup cluster start mytidb"
  sleep 40
}

# db_init initialises the database, get slowdown_ip and pid
function db_init {
  if [ "$exptype" == "follower" ]; then
    followerip=$s1
    /home/tidb/.tiup/bin/tiup ctl pd config set label-property reject-leader dc 1 -u http://"$pd":2379     # leader is restricted to s3
    followerpid=$(ssh -i ~/.ssh/id_rsa tidb@"$followerip" "pgrep tikv-server")
    slowdownpid=$followerpid
    slowdownip=$followerip
    echo $exptype slowdownip slowdownpid
  elif [ "$exptype" == "leader" ]; then
    leaderip=$(python3 getleader.py $pd)
    leaderpid=$(ssh -i ~/.ssh/id_rsa tidb@"$leaderip" "pgrep tikv-server")
    slowdownpid=$leaderpid
    slowdownip=$leaderip
    echo $exptype slowdownip slowdownpid
  else
    # Nothing to do
    echo ""
  fi
}

# ycsb_load is used to run the ycsb load and wait until it completes.
function ycsb_load {
#  ./bin/ycsb load mongodb -s -P $workload -p mongodb.url=mongodb://$primaryip:27017/ycsb?w=majority&readConcernLevel=majority ; wait $!
  /home/tidb/go-ycsb load tikv -P $workload -p tikv.pd="$pd":2379 --threads=1 ; wait $!
}

# ycsb run exectues the given workload and waits for it to complete
function ycsb_run {
#  ./bin/ycsb run mongodb -s -P $workload  -p maxexecutiontime=$ycsbruntime -p mongodb.url="mongodb://$primaryip:27017/ycsb?w=majority&readConcernLevel=majority" > "$dirname"/exp"$expno"_trial_"$i".txt ; wait $!
  /home/tidb/go-ycsb run tikv -P $workload -p tikv.pd="$pd":2379 > "$dirname"/exp"$expno"_trial_"$i".txt & ppid=$! ; sleep $ycsbruntime ; kill -INT $ppid
}

# cleanup is called at the end of the given trial of an experiment
function cleanup {
    ssh -i ~/.ssh/id_rsa tidb@"$s1" "sudo cgdelete cpu:db cpu:cpulow cpu:cpuhigh blkio:db memory:db ; true"
    ssh -i ~/.ssh/id_rsa tidb@"$s1" "sudo /sbin/tc qdisc del dev eth0 root ; true"
#    ssh -i ~/.ssh/id_rsa tidb@"$s1" "sudo pkill dd ; rm /data1/tmp.txt -f"
    #ssh -i ~/.ssh/id_rsa tidb@"$s1" "sudo pkill deadloop"
    sleep 5
    ssh -i ~/.ssh/id_rsa tidb@"$s2" "sudo cgdelete cpu:db cpu:cpulow cpu:cpuhigh blkio:db memory:db ; true"
    ssh -i ~/.ssh/id_rsa tidb@"$s2" "sudo /sbin/tc qdisc del dev eth0 root ; true"
#    ssh -i ~/.ssh/id_rsa tidb@"$s2" "sudo pkill dd ; rm /data1/tmp.txt -f"
    #ssh -i ~/.ssh/id_rsa tidb@"$s2" "sudo pkill deadloop"
    sleep 5
    ssh -i ~/.ssh/id_rsa tidb@"$s3" "sudo cgdelete cpu:db cpu:cpulow cpu:cpuhigh blkio:db memory:db ; true"
    ssh -i ~/.ssh/id_rsa tidb@"$s3" "sudo /sbin/tc qdisc del dev eth0 root ; true"
#    ssh -i ~/.ssh/id_rsa tidb@"$s3" "sudo pkill dd ; rm /data1/tmp.txt -f"
    #ssh -i ~/.ssh/id_rsa tidb@"$s3" "sudo pkill deadloop"
    sleep 5
}

# stop_servers turns off the VM instances
function stop_servers {
  if [ "$host" == "gcp" ]; then
    gcloud compute instances stop "$s1name" "$s2name" "$s3name" --zone="$serverZone"
  elif [ "$host" == "azure" ]; then
    az vm deallocate --resource-group DepFast --name "$s1name"
    az vm deallocate --resource-group DepFast --name "$s2name"
    az vm deallocate --resource-group DepFast --name "$s3name"
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
    cleanup
#    data_cleanup

    # 3. Create data directories
    init

    # 4. SSH to all the machines and start db
    start_db

    # 5. ycsb load
    ycsb_load

    # 6. Init
    db_init

    # 7. Run experiment if this is not a no slow
    if [ "$exptype" != "noslow1" ] && [ "$exptype" != "noslow2" ] ; then
      run_experiment
    fi

    # 8. ycsb run
    ycsb_run

    # 9. cleanup
    cleanup
    data_cleanup
    
    # 10. Power off all the VMs
    stop_servers
  done
}

test_start tidb
test_run

# Make sure either shutdown is executed after you run this script or uncomment the last line
# sudo shutdown -h now
