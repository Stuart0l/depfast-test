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

# Min throughput experiments
./start_experiment.sh $iterations workloads/workloada_more $ycsbruntime 1 azure noslowminthroughput disk swapoff 3 $serverRegex $threadsycsb
./start_experiment.sh $iterations workloads/workloada_more $ycsbruntime 1 azure minthroughput disk swapoff 3 $serverRegex $threadsycsb
./start_experiment.sh $iterations workloads/workloada_more $ycsbruntime 2 azure minthroughput disk swapoff 3 $serverRegex $threadsycsb
./start_experiment.sh $iterations workloads/workloada_more $ycsbruntime 3 azure minthroughput disk swapoff 3 $serverRegex $threadsycsb
./start_experiment.sh $iterations workloads/workloada_more $ycsbruntime 4 azure minthroughput disk swapoff 3 $serverRegex $threadsycsb
./start_experiment.sh $iterations workloads/workloada_more $ycsbruntime 5 azure minthroughput disk swapoff 3 $serverRegex $threadsycsb

# Max throughput experiments
./start_experiment.sh $iterations workloads/workloada_more $ycsbruntime 1 azure noslowmaxthroughput disk swapoff 3 $serverRegex $threadsycsb
./start_experiment.sh $iterations workloads/workloada_more $ycsbruntime 1 azure maxthroughput disk swapoff 3 $serverRegex $threadsycsb
./start_experiment.sh $iterations workloads/workloada_more $ycsbruntime 2 azure maxthroughput disk swapoff 3 $serverRegex $threadsycsb
./start_experiment.sh $iterations workloads/workloada_more $ycsbruntime 3 azure maxthroughput disk swapoff 3 $serverRegex $threadsycsb
./start_experiment.sh $iterations workloads/workloada_more $ycsbruntime 4 azure maxthroughput disk swapoff 3 $serverRegex $threadsycsb
./start_experiment.sh $iterations workloads/workloada_more $ycsbruntime 5 azure maxthroughput disk swapoff 3 $serverRegex $threadsycsb
