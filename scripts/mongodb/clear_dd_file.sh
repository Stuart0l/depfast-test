#!/bin/bash

while true;
do
	cat /dev/null > /data1/tmp.txt
	echo "file content removed"
	sleep 5s
	echo "slept for 5s"
done

