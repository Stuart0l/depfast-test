#!/bin/python
import csv
import pdb
import sys

def main(argv):
    reader = csv.DictReader(open('range_status.csv'))
    range_map = {}
    for row in reader:
        #pdb.set_trace()
        range_map[row['address'].split(':')[0]] = {
            'replicas_leaders': row['replicas_leaders'],
            'replicas_leaseholders': row['replicas_leaseholders']
        }

    count = 0
    reader = csv.DictReader(open('range_count.csv'))
    for row in reader:
        count = row['count']

    primaryip = argv[0]
    # Verify that count of the pinned leader node matches
    assert (int(range_map[primaryip]['replicas_leaders']) == int(count)),"Leaders count {0} of pinned node {1} does not match total range count of {2}".format(range_map[primaryip]['replicas_leaders'],primaryip, count)
    assert (int(range_map[primaryip]['replicas_leaseholders']) == int(range_map[primaryip]['replicas_leaders'])), "Leaders count {0} is not equal to leaseholder count {1}".format(range_map[primaryip]['replicas_leaders'], range_map[primaryip]['replicas_leaseholders'])

    # Verify that there are no leaders and leaseholders on other nodes
    for k, v in range_map.items():
        if k != primaryip:
            assert (int(v['replicas_leaders']) == 0),'Leader found on a follower node {0}'.format(k)
            assert (int(v['replicas_leaseholders']) == 0),'Leaseholder found on a follower node {0}'.format(k)

if __name__ == "__main__":
    main(sys.argv[1:])
