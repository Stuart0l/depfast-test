#!/bin/bash

# disk
# slow follower
./etcd.sh 5 1 azure follower disk swapoff 3 xuhao-01
./etcd.sh 5 2 azure follower disk swapoff 3 xuhao-01
./etcd.sh 5 3 azure follower disk swapoff 3 xuhao-01
./etcd.sh 5 4 azure follower disk swapoff 3 xuhao-01
./etcd.sh 5 5 azure follower disk swapoff 3 xuhao-01


# # no slow
# ./etcd.sh 5 1 azure noslowfollower disk swapoff 3 xuhao-01
./etcd.sh 5 1 azure noslowfollower disk swapon 3 xuhao-01

./etcd.sh 5 6 azure follower disk swapon 3 xuhao-01

# # slow leader
# ./etcd.sh 5 1 azure leader disk swapoff 3 xuhao-01
# ./etcd.sh 5 2 azure leader disk swapoff 3 xuhao-01
# ./etcd.sh 5 3 azure leader disk swapoff 3 xuhao-01
# ./etcd.sh 5 4 azure leader disk swapoff 3 xuhao-01
# ./etcd.sh 5 5 azure leader disk swapoff 3 xuhao-01

# tmpfs
# slow follower
# ./etcd.sh 4 1 azure follower memory swapoff 3 xuhao-01
# ./etcd.sh 2 2 azure follower memory swapoff 3 xuhao-01
# ./etcd.sh 5 5 azure follower memory swapoff 3 xuhao-01
# ./etcd.sh 5 6 azure follower memory swapon 3 xuhao-01

# no slow
# ./etcd.sh 5 1 azure noslowfollower memory swapoff 3 xuhao-01
# ./etcd.sh 5 1 azure noslowfollower memory swapon 3 xuhao-01

# # slow leader
# ./etcd.sh 5 1 azure leader memory swapoff 3 xuhao-01
# ./etcd.sh 5 2 azure leader memory swapoff 3 xuhao-01
# ./etcd.sh 5 5 azure leader memory swapoff 3 xuhao-01
