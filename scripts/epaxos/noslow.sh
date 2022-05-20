#!/bin/bash

date=$(date +"%Y%m%d%s")

if [ "$#" -ne 1 ]; then
	echo "1st arg - number of iterations"
	# echo "2nd arg - number of poisson"
	exit 1
fi

iterations=$1
# poisson=(8 16 32 64 128 256 300)
threads=(140)
# poisson=(200 800 3200)
# poisson=(-1)
or=(10)
poisson=(-1)
conflict=(100)

for c in ${conflict[@]}
do
	for p in ${poisson[@]}
	do
		for t in ${threads[@]}
		do
			for o in ${or[@]}
			do
				for (( i=1; i<=$iterations; i++ ))
				do
					# echo "thread $p iter $i"
					name=thrifty_c${c}_p${p}_or${o}_"$t"_"$date"
					echo "Running experiment $name"
					# ./janus-az-3VM-disk-epaxos.sh 01 $name $p 300 0 follower
					./original-3VM-epaxos.sh 01 $name 120 $t
					# ./original-5VM-LAN-epaxos.sh 05 $name 120 $p $o $c $t
					# ./original-5VM-WAN-epaxos.sh 01 $name 120 $p $o $c $t
				done
			done
		done
	done
done