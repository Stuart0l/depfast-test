#!/bin/bash

while(true)
do
        ssh -i ~/.ssh/id_rsa "$ip" "sudo sh -c 'nohup taskset -ac 2 dd if=/dev/zero of=/data1/tmp.txt bs=1000 count=1600000 conv=notrunc'"
done

