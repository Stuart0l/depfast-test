import json
import os
import sys
import time

def main(argv):
    pd=argv[1]
    sw=argv[2]
    sec=str(int(time.time()))
    #cmd='curl http://'+pd+':9090/api/v1/query?query=tikv_raftstore_region_count%7Btype%3D%22leader%22%7D'
    cmd='curl http://'+pd+':9090/api/v1/query?query=tikv_grpc_msg_duration_seconds_count%7Btype%3D%22raw_put%22%7D&time='+sec
    res=os.popen(cmd).read()
    dres=json.loads(res)
    nodes=len(dres['data']['result'])    #int(argv[2])
    maxcnt=0
    mincnt=dres['data']['result'][0]['value'][1]
    maxip=dres['data']['result'][0]['metric']['instance'].replace(':20180','')
    minip=dres['data']['result'][0]['metric']['instance'].replace(':20180','')
    for i in range(nodes):
        cnt=int(dres['data']['result'][i]['value'][1])
        ip=dres['data']['result'][i]['metric']['instance'].replace(':20180','')
        #print(cnt, ip)
        if(cnt>maxcnt):
            maxcnt=cnt
            maxip=ip
        if(cnt<mincnt):
            mincnt=cnt
            minip=ip
    if(sw=='min'):
        print(minip)
    else:
        print(maxip)

if __name__ == "__main__":
    main(sys.argv)

