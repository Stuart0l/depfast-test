import json
import os
import sys

def main(argv):
    pd=argv[1]
    nodes=int(argv[2])
    cmd='curl http://'+pd+':9090/api/v1/query?query=tikv_raftstore_region_count%7Btype%3D%22leader%22%7D'
    res=os.popen(cmd).read()
    dres=json.loads(res)
    maxcnt=0
    maxip=dres['data']['result'][0]['metric']['instance'].replace(':20180','')
    for i in range(nodes):
        cnt=int(dres['data']['result'][i]['value'][1])
        ip=dres['data']['result'][i]['metric']['instance'].replace(':20180','')
        #print(cnt, ip)
        if(cnt>maxcnt):
            maxcnt=cnt
            maxip=ip
    print(maxip)

if __name__ == "__main__":
    main(sys.argv)

