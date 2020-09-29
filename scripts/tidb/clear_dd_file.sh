#!/bin/bash

while true;
do
	cat /dev/null > /data1/tmp.txt
	echo "file content removed"
	sleep 10s
	echo "slept for 1s"
done

