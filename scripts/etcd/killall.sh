#!/bin/bash

for pid in $(ps x | grep "etcd\|etcdctl\|benchmark" | awk '{print $1}'); do
	kill -9 $pid
done