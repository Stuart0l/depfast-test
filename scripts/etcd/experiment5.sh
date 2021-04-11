#!/bin/bash

set -ex

ip=$1
username=$2

ssh -i ~/.ssh/id_rsa $username@"$ip" "sudo sh -c 'sudo /sbin/tc qdisc add dev eth0 root netem delay 400ms'"
