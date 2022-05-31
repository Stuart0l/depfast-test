import json
import sys
import pdb

def main(argv):
    if len(argv) == 0:
        print("No json file name specified. Exiting")
        return 0
    fileName = argv[0]

    with open(fileName) as json_file:
        data = json.load(json_file)

        follower = []
        leader = ""
        #pdb.set_trace()
        for row in data:
            if row['Status']['leader'] == row['Status']['header']['member_id']:
                leader = row['Endpoint'].split(":")[0]
            else:
                follower.append(row['Endpoint'].split(":")[0])
            
        print("leader=", leader, sep='')

        n_slow = len(follower) // 2
        for i, fo in enumerate(follower):
            if i >= n_slow:
                break
            print("follower{}=".format(i), fo, sep='')

if __name__ == "__main__":
   main(sys.argv[1:])
