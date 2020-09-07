#!/bin/bash

set -ex

ip=$1

ssh -i ~/.ssh/id_rsa "$ip" "sudo sh -c 'sudo nohup taskset -ac 1 dd if=/dev/zero of=/data1/tmp.txt bs=1000 count=60000000 > /dev/null 2>&1 &'"


#60GB

