#!/bin/bash

set -x

nClients=$1
nConns=$nClients

total=$((nConns * 10000))
rep=3
dataDir="/db/data.etcd"
expDir="experiments"
name=$2
rep=$3
exp=$4

declare -A hostIPMap

# setup
TOKEN=token-01
CLUSTER_STATE=new
# Name is hostname
NAME_1=server1
NAME_2=server2
NAME_3=server3
NAME_4=server4
NAME_5=server5
# Host is ip
HOST_1=10.0.0.5
HOST_2=10.0.0.6
HOST_3=10.0.0.7
HOST_4=10.0.0.8
HOST_5=10.0.0.9
CLIENT=10.0.0.11
CLUSTER=${NAME_1}=http://${HOST_1}:2380,${NAME_2}=http://${HOST_2}:2380,${NAME_3}=http://${HOST_3}:2380
export ETCDCTL_API=3
ENDPOINTS=$HOST_1:2379,$HOST_2:2379,$HOST_3:2379
if [ $rep -eq 5 ]; then
	CLUSTER=$CLUSTER,${NAME_4}=http://${HOST_4}:2380,${NAME_5}=http://${HOST_5}:2380
	ENDPOINTS=$ENDPOINTS,$HOST_4:2379,$HOST_5:2379
fi

hostIPMap[$NAME_1]=$HOST_1
hostIPMap[$NAME_2]=$HOST_2
hostIPMap[$NAME_3]=$HOST_3
hostIPMap[$NAME_4]=$HOST_4
hostIPMap[$NAME_5]=$HOST_5

# cleanup
ssh -o StrictHostKeyChecking=no $CLIENT " ./killall.sh "
for i in $(seq 1 $rep); do
	THIS_NAME=server$i
	THIS_IP=${hostIPMap[$THIS_NAME]}
	ssh -o StrictHostKeyChecking=no $THIS_IP " ./killall.sh "
	ssh -o StrictHostKeyChecking=no $THIS_IP " sudo rm -rf $dataDir/* "
done

if [ $exp -eq 6 ]; then
	ssh -o StrictHostKeyChecking=no $followerip "\
		sudo cgcreate -a $USER:$USER -t $USER:$USER -g memory:janus; \
		echo 50M | sudo tee /sys/fs/cgroup/memory/janus/memory.limit_in_bytes; \
		sudo sysctl vm.swappiness=60 ; sudo swapoff -a && sudo swapon -a ; sudo swapon /db/swapfile; "
fi

# start server
for i in $(seq 1 $rep); do
	THIS_NAME=server$i
	THIS_IP=${hostIPMap[$THIS_NAME]}
	ssh -o StrictHostKeyChecking=no $THIS_IP "\
		ulimit -n 4096; \
		taskset -ac 1 \
		nohup etcd --data-dir=$dataDir --name ${THIS_NAME} \
		--quota-backend-bytes=$((8*1024*1024*1024)) \
		--initial-advertise-peer-urls http://${THIS_IP}:2380 \
		--listen-peer-urls http://${THIS_IP}:2380 \
		--advertise-client-urls http://${THIS_IP}:2379 \
		--listen-client-urls http://${THIS_IP}:2379 \
		--initial-cluster ${CLUSTER} \
		--initial-cluster-state ${CLUSTER_STATE} \
		--initial-cluster-token ${TOKEN} \
		> /db/etcd.log 2>&1 &"
done

sleep 5s

# Check status
etcdctl --write-out=table --endpoints=$ENDPOINTS endpoint status || true

# find follower leader
rm -f etcd.json jsonres
etcdctl --write-out=json --endpoints=$ENDPOINTS endpoint status > etcd.json
python3 etcd_helper.py etcd.json > jsonres
primaryip=$(cat jsonres | grep -Eo 'leader=.{1,30}' | cut -d'=' -f2-)
followerip1=$(cat jsonres | grep -Eo 'follower0=.{1,30}' | cut -d'=' -f2-)
followerip2=$(cat jsonres | grep -Eo 'follower1=.{1,30}' | cut -d'=' -f2-)

if [ $rep -eq 3 ]; then
	followers=($followerip1)
else
	followers=($followerip1, $followerip2)
fi

# start experiment
if [ $exp -eq 1 ]; then
	for followerip in ${followers[@]}
	do
	ssh -o StrictHostKeyChecking=no $followerip " \
		pid=\`ps -A | grep 'etcd' | awk '{print \$1}' | cut -f2 -d= | cut -f1 -d,\`; \
		sudo mkdir /sys/fs/cgroup/cpu/janus; \
		echo 50000 | sudo tee /sys/fs/cgroup/cpu/janus/cpu.cfs_quota_us; \
		echo 1000000 | sudo tee /sys/fs/cgroup/cpu/janus/cpu.cfs_period_us; \
		echo \$pid | sudo tee /sys/fs/cgroup/cpu/janus/cgroup.procs"
	done
elif [ $exp -eq 2 ]; then
	for followerip in ${followers[@]}
	do
	ssh -o StrictHostKeyChecking=no -f $followerip " \
		pid=\`ps -A | grep 'etcd' | awk '{print \$1}' | cut -f2 -d= | cut -f1 -d,\`; \
		taskset -ac 1 ~/inf & export inf=\$!; \
		sudo mkdir /sys/fs/cgroup/cpu/cpulow /sys/fs/cgroup/cpu/cpuhigh; \
		echo 64 | sudo tee /sys/fs/cgroup/cpu/cpulow/cpu.shares; \
		echo \$pid | sudo tee /sys/fs/cgroup/cpu/cpulow/cgroup.procs; \
		echo \$inf | sudo tee /sys/fs/cgroup/cpu/cpuhigh/cgroup.procs;"
	done
elif [ $exp -eq 3 ]; then
	for followerip in ${followers[@]}
	do
	ssh -o StrictHostKeyChecking=no $followerip " \
		pid=\`ps -A | grep 'etcd' | awk '{print \$1}' | cut -f2 -d= | cut -f1 -d,\`; \
		sync; echo 3 | sudo tee /proc/sys/vm/drop_caches; \
		sudo mkdir /sys/fs/cgroup/blkio/janus; \
		echo '8:32 131072' | sudo tee /sys/fs/cgroup/blkio/janus/blkio.throttle.read_bps_device; \
		echo '8:32 131072' | sudo tee /sys/fs/cgroup/blkio/janus/blkio.throttle.write_bps_device; \
		echo \$pid | sudo tee /sys/fs/cgroup/blkio/janus/cgroup.procs;"
	done
elif [ $exp -eq 4 ]; then
	for followerip in ${followers[@]}
	do
	ssh -o StrictHostKeyChecking=no $followerip " \
		sudo nohup taskset -ac 2 dd if=/dev/zero of=/db/tmp.txt bs=1000 count=200000000 > /dev/null 2>&1 &"
	done
elif [ $exp -eq 5 ]; then
	for followerip in ${followers[@]}
	do
	ssh -o StrictHostKeyChecking=no $followerip " \
		sudo /sbin/tc qdisc add dev eth0 root netem delay 40ms"
	done
elif [ $exp -eq 6 ]; then
	for followerip in ${followers[@]}
	do
	ssh -o StrictHostKeyChecking=no $followerip " \
		sudo cgcreate -a $USER:$USER -t $USER:$USER -g memory:janus; \
		echo 50M | sudo tee /sys/fs/cgroup/memory/janus/memory.limit_in_bytes; \
		sudo sysctl vm.swappiness=60 ; sudo swapoff -a && sudo swapon -a ; sudo swapon /db/swapfile; \
		pid=\`ps -A | grep 'etcd' | awk '{print \$1}' | cut -f2 -d= | cut -f1 -d,\`; \
		sudo kill -9 \$pid; \
		cgexec -g memory:janus taskset -ac 1 \
		nohup etcd --data-dir=$dataDir --name ${followerip}_rejoin \
		--quota-backend-bytes=$((8*1024*1024*1024)) \
		--initial-advertise-peer-urls http://${followerip}:2380 \
		--listen-peer-urls http://${followerip}:2380 \
		--advertise-client-urls http://${followerip}:2379 \
		--listen-client-urls http://${followerip}:2379 \
		--initial-cluster ${CLUSTER} \
		--initial-cluster-state existing \
		--initial-cluster-token ${TOKEN} \
		> /db/etcd.log 2>&1 & "
	done
	sleep 3
	etcdctl --write-out=table --endpoints=$ENDPOINTS endpoint status || true
else
	echo "run exp $exp"
fi

sleep 5

# run benchmark
mkdir -p $expDir
ssh -o StrictHostKeyChecking=no $CLIENT "\
	ulimit -n 4096; \
	nohup benchmark --endpoints=$primaryip:2380 \
	--target-leader \
	--conns=$nConns --clients=$nClients \
	put --key-size=8 --total=$total --val-size=256 \
	--sequential-keys" \
	2>&1 > $expDir/$name.txt

# stop experiment
if [ $exp -eq 1 ]; then
	ssh -o StrictHostKeyChecking=no $followerip " \
		pid=\`ps -A | grep 'etcd' | awk '{print \$1}' | cut -f2 -d= | cut -f1 -d,\`; \
		echo \$pid | sudo tee /sys/fs/cgroup/cpu/cgroup.procs "
elif [ $exp -eq 2 ]; then
	ssh -o StrictHostKeyChecking=no $followerip " \
		sudo cgdelete cpu:cpuhigh cpu:cpulow;
		sudo pkill inf "
elif [ $exp -eq 3 ]; then
	ssh -o StrictHostKeyChecking=no $followerip " \
		pid=\`ps -A | grep 'etcd' | awk '{print \$1}' | cut -f2 -d= | cut -f1 -d,\`; \
		echo \$pid | sudo tee /sys/fs/cgroup/cpu/cgroup.procs "
elif [ $exp -eq 4 ]; then
	ssh -o StrictHostKeyChecking=no $followerip " \
		pid=`ps aux | grep 'dd if' | head -1 | awk '{print $2}'`; \
		pid2=`ps aux | grep 'dd if' | head -2 | tail -1 | awk '{print $2}'`; \
		echo \$pid; echo \$pid2; \
		sudo kill -9 \$pid; \
		sudo kill -9 \$pid2; \
		sudo pkill dd; \
		sudo sh -c 'echo 3 > /proc/sys/vm/drop_caches'; \
		sudo rm /db/tmp.txt "
elif [ $exp -eq 5 ]; then
	ssh -o StrictHostKeyChecking=no $followerip " \
		sudo /sbin/tc qdisc del dev eth0 root netem"
elif [ $exp -eq 6 ]; then
	ssh -o StrictHostKeyChecking=no $followerip " \
		pid=\`ps -A | grep 'etcd' | awk '{print \$1}' | cut -f2 -d= | cut -f1 -d,\`; \
		echo \$pid | sudo tee /sys/fs/cgroup/cpu/cgroup.procs; \
		sudo swapoff /db/swapfile; \
		sudo cgdelete memory:janus;"
else
	echo "end exp $exp"
fi

# # cleanup
ssh -o StrictHostKeyChecking=no $CLIENT " ./killall.sh "
for i in $(seq 1 $rep); do
	THIS_NAME=server$i
	THIS_IP=${hostIPMap[$THIS_NAME]}
	ssh -o StrictHostKeyChecking=no $THIS_IP " ./killall.sh "
	ssh -o StrictHostKeyChecking=no $THIS_IP " sudo rm -rf $dataDir/* "
done

tput=`cat $expDir/$name.txt | grep "Requests/sec" | awk '{print $2}' | cut -f1 -d,`
avg=`cat $expDir/$name.txt | grep "Average" | awk '{print $2}' | cut -f1 -d,`
med=`cat $expDir/$name.txt | grep "50:" | awk '{print $2}' | cut -f1 -d,`
p99=`cat $expDir/$name.txt | grep "99:" | awk '{print $2}' | cut -f1 -d,`

echo "$name, $tput, $avg, $med, $p99, $nClients" >> result${exp}_${rep}.csv
