import json
import sys
import pdb

totalNodes = 3
nodesThroughput = {
            1: 0.0,
            2: 0.0,
            3: 0.0
        }
debug = False

def main(argv):
    if len(argv) == 0:
        print("No json file name specified. Exiting")
        return 0
    fileName = argv[0]

    # Measuring throughput comprises of both WPS(Write per second) + QPS(Query
    # per second)
    with open(fileName) as json_file:
        data = json.load(json_file)

        # Get total number of ranges
        ranges = data['ranges']

        # Sort them 
        intRanges = sorted([ int(x) for x in ranges ])
        if debug:
            print("Total ranges")
            print(intRanges)

        # For each range, fetch the stats
        maxVal = 0
        node = 0
        rangeVal = 0
        for i in intRanges:
            if debug:
                print("range", i)
            for n in range(totalNodes):
                # Find node id
                nodeid = data['ranges'][str(i)]['nodes'][n]['nodeId']
                qps = round(data['ranges'][str(i)]['nodes'][n]['range']['stats']['queriesPerSecond'],2)
                wps = round(data['ranges'][str(i)]['nodes'][n]['range']['stats']['writesPerSecond'],2)
                tp = qps + wps
                if debug:
                    print('tp for node id', nodeid, tp)
                nodesThroughput[nodeid] += tp

        # Average out the throughput
        maxTP = 0
        maxNodeId = 1
        for k in nodesThroughput:
            nodesThroughput[k] = nodesThroughput[k]/len(intRanges)*1.0
            if debug:
                print("Node", k, "throughput is", nodesThroughput[k])
            if nodesThroughput[k] > maxTP:
                maxTP = nodesThroughput[k]
                maxNodeId = k

        print("maxthroughput=", maxTP, sep='')
        print("nodeid=", maxNodeId, sep='')

if __name__ == "__main__":
   main(sys.argv[1:])
