#!/bin/bash

date=$(date +"%Y%m%d%s")

if [ "$#" -ne 1 ]; then
	echo "1st arg - number of iterations"
	echo "2nd arg - number of threads"
	exit 1
fi

iterations=$1
threads=(8)
# threads=(8 16 32 64 128 256 300)
# threads=(16 32 64 128 256)

for t in ${threads[@]}
do
	for (( i=1; i<=$iterations; i++ ))
	do
		# echo "thread $t iter $i"
		name=noslow_"$t"_trail_"$i"_"$date"
		echo "Running experiment $name"
		# ./janus-az-3VM-disk-epaxos.sh 01 $name $t 300 0 follower
		./original-3VM-epaxos.sh 01 $name 300 $t
	done
done
