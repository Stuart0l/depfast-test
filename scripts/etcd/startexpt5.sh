#!/bin/bash

set -x

nClients=$1
nConns=$nClients
total=$((nConns * 2000))
rep=5
dataDir="/db/data.etcd"
expDir="experiments"
expName=$2

declare -A hostIPMap

sudo mv host$rep /etc/hosts
rm ~/.ssh/known_hosts

# cleanup
totalNodes=$((rep + 2))
for i in $(seq 2 $totalNodes); do
	ssh -o StrictHostKeyChecking=no node-$i " ./killall.sh "
	ssh -o StrictHostKeyChecking=no node-$i " sudo rm -rf $dataDir/* "
done

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
HOST_1=10.0.0.13
HOST_2=10.0.0.14
HOST_3=10.0.0.15
HOST_4=10.0.0.55
HOST_5=10.0.0.58
CLUSTER=${NAME_1}=http://${HOST_1}:2380,${NAME_2}=http://${HOST_2}:2380,${NAME_3}=http://${HOST_3}:2380,${NAME_4}=http://${HOST_4}:2380,${NAME_5}=http://${HOST_5}:2380
export ETCDCTL_API=3
ENDPOINTS=$HOST_1:2379,$HOST_2:2379,$HOST_3:2379,$HOST_4:2379,$HOST_5:2379

hostIPMap[$NAME_1]=$HOST_1
hostIPMap[$NAME_2]=$HOST_2
hostIPMap[$NAME_3]=$HOST_3
hostIPMap[$NAME_4]=$HOST_4
hostIPMap[$NAME_5]=$HOST_5


# start server
for i in $(seq 2 $((rep + 1))); do
	THIS_NAME=server$((i - 1))
	THIS_IP=${hostIPMap[$THIS_NAME]}
	ssh -o StrictHostKeyChecking=no node-$i "\
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

# run benchmark
mkdir -p $expDir
ssh -o StrictHostKeyChecking=no node-$((rep + 2)) "\
	nohup benchmark --endpoints=$primaryip:2380 \
	--target-leader \
	--conns=$nConns --clients=$nClients \
	put --key-size=8 --total=$total --val-size=256 \
	--sequential-keys" \
	2>&1 > $expDir/$expName.txt

# # cleanup
totalNodes=$((rep + 1))
for i in $(seq 2 $totalNodes); do
	ssh -o StrictHostKeyChecking=no node-$i " ./killall.sh "
	ssh -o StrictHostKeyChecking=no node-$i " sudo rm -rf $dataDir "
done

tput=`cat $expDir/$expName.txt | grep "Requests/sec" | awk '{print $2}' | cut -f1 -d,`
avg=`cat $expDir/$expName.txt | grep "Average" | awk '{print $2}' | cut -f1 -d,`
med=`cat $expDir/$expName.txt | grep "50% in" | awk '{print $3}' | cut -f1 -d,`
p99=`cat $expDir/$expName.txt | grep "99% in" | awk '{print $3}' | cut -f1 -d,`

echo "$expName, $tput, $avg, $med, $p99, $nConns" >> result0_$rep.csv