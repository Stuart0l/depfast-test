 #!/bin/bash

 set -ex

 ip=$1

 # Trigger dd command
 ssh -i ~/.ssh/id_rsa "$ip" "sh -c 'nohup taskset -ac 1 ~/launch_dd.sh > /dev/null 2>&1 &'"

# ssh -i ~/.ssh/id_rsa "$ip" "sudo sh -c 'sudo nohup taskset -ac 1 dd if=/dev/zero of=/data/tmp.txt bs=1000 count=200000000 > /dev/null 2>&1 &'"
