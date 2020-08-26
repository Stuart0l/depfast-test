#!/bin/bash

set -ex

if [ "$#" -ne 4 ]; then
  echo "5 args needed"
  echo "1st arg - no of iterations"
  echo "2nd arg - ycsb run time - secs to run"
  echo "3rd arg - server regex"
  echo "4th arg - no of threads for ycsb"
  exit 1
fi

iterations=$1
ycsbruntime=$2
serverRegex=$3
threadsycsb=$4

# Follower experiments
./start_experiment.sh $iterations workloads/workloada_more $ycsbruntime 1 azure noslowfollower memory swapoff 3 $serverRegex $threadsycsb
./start_experiment.sh $iterations workloads/workloada_more $ycsbruntime 1 azure noslowfollower memory swapon 3 $serverRegex $threadsycsb

./start_experiment.sh $iterations workloads/workloada_more $ycsbruntime 1 azure follower memory swapoff 3 $serverRegex $threadsycsb
./start_experiment.sh $iterations workloads/workloada_more $ycsbruntime 2 azure follower memory swapoff 3 $serverRegex $threadsycsb
./start_experiment.sh $iterations workloads/workloada_more $ycsbruntime 5 azure follower memory swapoff 3 $serverRegex $threadsycsb

./start_experiment.sh $iterations workloads/workloada_more $ycsbruntime 6 azure follower memory swapon 3 $serverRegex $threadsycsb

# Min throughput experiments
./start_experiment.sh $iterations workloads/workloada_more $ycsbruntime 1 azure noslowminthroughput memory swapoff 3 $serverRegex $threadsycsb
./start_experiment.sh $iterations workloads/workloada_more $ycsbruntime 1 azure noslowminthroughput memory swapon 3 $serverRegex $threadsycsb

./start_experiment.sh $iterations workloads/workloada_more $ycsbruntime 1 azure minthroughput memory swapoff 3 $serverRegex $threadsycsb
./start_experiment.sh $iterations workloads/workloada_more $ycsbruntime 2 azure minthroughput memory swapoff 3 $serverRegex $threadsycsb
./start_experiment.sh $iterations workloads/workloada_more $ycsbruntime 5 azure minthroughput memory swapoff 3 $serverRegex $threadsycsb

./start_experiment.sh $iterations workloads/workloada_more $ycsbruntime 6 azure minthroughput memory swapon 3 $serverRegex $threadsycsb

# Max throughput experiments
./start_experiment.sh $iterations workloads/workloada_more $ycsbruntime 1 azure noslowmaxthroughput memory swapoff 3 $serverRegex $threadsycsb
./start_experiment.sh $iterations workloads/workloada_more $ycsbruntime 1 azure noslowmaxthroughput memory swapon 3 $serverRegex $threadsycsb

./start_experiment.sh $iterations workloads/workloada_more $ycsbruntime 1 azure maxthroughput memory swapoff 3 $serverRegex $threadsycsb
./start_experiment.sh $iterations workloads/workloada_more $ycsbruntime 2 azure maxthroughput memory swapoff 3 $serverRegex $threadsycsb
./start_experiment.sh $iterations workloads/workloada_more $ycsbruntime 5 azure maxthroughput memory swapoff 3 $serverRegex $threadsycsb

./start_experiment.sh $iterations workloads/workloada_more $ycsbruntime 6 azure maxthroughput memory swapon 3 $serverRegex $threadsycsb