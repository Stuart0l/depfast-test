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

# 1 client - Follower experiments
./start_experiment.sh $iterations workloads/workloada_more $ycsbruntime 3 azure follower disk swapoff 3 $serverRegex 1

# 1 client - Leader experiments
./start_experiment.sh $iterations workloads/workloada_more $ycsbruntime 3 azure leader disk swapoff 3 $serverRegex 1

# Saturate experiments - leader
./start_experiment.sh $iterations workloads/workloada_more $ycsbruntime 1 azure noslow disk swapoff 3 $serverRegex 35

./start_experiment.sh $iterations workloads/workloada_more $ycsbruntime 1 azure leader disk swapoff 3 $serverRegex 35
./start_experiment.sh $iterations workloads/workloada_more $ycsbruntime 2 azure leader disk swapoff 3 $serverRegex 35
./start_experiment.sh $iterations workloads/workloada_more $ycsbruntime 3 azure leader disk swapoff 3 $serverRegex 35
./start_experiment.sh $iterations workloads/workloada_more $ycsbruntime 4 azure leader disk swapoff 3 $serverRegex 35
./start_experiment.sh $iterations workloads/workloada_more $ycsbruntime 5 azure leader disk swapoff 3 $serverRegex 35

# Saturate experiments - follower
./start_experiment.sh $iterations workloads/workloada_more $ycsbruntime 1 azure follower disk swapoff 3 $serverRegex 35
./start_experiment.sh $iterations workloads/workloada_more $ycsbruntime 2 azure follower disk swapoff 3 $serverRegex 35
./start_experiment.sh $iterations workloads/workloada_more $ycsbruntime 3 azure follower disk swapoff 3 $serverRegex 35
./start_experiment.sh $iterations workloads/workloada_more $ycsbruntime 4 azure follower disk swapoff 3 $serverRegex 35
./start_experiment.sh $iterations workloads/workloada_more $ycsbruntime 5 azure follower disk swapoff 3 $serverRegex 35