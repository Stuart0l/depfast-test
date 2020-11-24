#!/usr/bin/python

import numpy as np  
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import time
import pdb
import sys

dirty = []
writeback = []

def main(argv):
    print("Dirty pages and writeback stats collector")
    total_time = int(argv[0])
    print "Running for ", total_time, " secs"

    count = 0
    while(count < total_time):
        meminfo = dict((i.split()[0].rstrip(':'),int(i.split()[1])) for i in open('/proc/meminfo').readlines())
        dirty.append(round(meminfo['Dirty']/1024.0, 1))
        writeback.append(round(meminfo['Writeback']/1024.0, 1))
        print("Time ", count, ", Dirty=",dirty[count], " Writeback=", writeback[count])
        time.sleep(1)
        count += 1

    # Plot the figures
    x = range(1, count + 1)
    plt.title("Dirty pages & writeback over time")  
    plt.xlabel("Time(in secs)")  
    plt.ylabel("Data size(in MB)")  
    plt.plot(x, dirty, color ="red", label="Dirty pages")
    plt.plot(x, writeback, color="green", label="Writeback")
    plt.legend()
    #plt.plot()
    plt.savefig('stats.png')
    print('Mean dirty pages:', np.mean(dirty), "Median:", np.median(dirty))
    print('Mean writeback:', np.mean(writeback), "Median:", np.median(writeback))
    #plt.show()

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print "One arg of total time needed"
        sys.exit(1)
    main(sys.argv[1:])
