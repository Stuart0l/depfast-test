record_stats.py generates a plot for writeback and dirty page value count per second.
The writeback and dirty page value is obtained from /proc/meminfo - https://access.redhat.com/solutions/406773

Argument 1 - total number of seconds for the script to run


----------

disk_contention.c
Custom program to simulate disk contention by writing to 5 files of size 2GB concurrently and doing fsync at the end. Repeat this infinitely.
Note: Compile using -lpthread  flag.
