#!/bin/bash

while true;
do
	cat /dev/null > /data/tmp.txt
	echo "file content removed"
	sleep 20s
	echo "slept for 20s"
done
