#!/bin/bash

set -ex

while(true)
do
    taskset -ac 1 dd if=/dev/zero of=/data1/tmp.txt bs=1000 count=1600000 conv=notrunc
done
