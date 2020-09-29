import json
import os
import sys
import time

def main(argv):
    pd=argv[1]
    sw=argv[2]
    sec=str(int(time.time()))
    #cmd='curl http://'+pd+':9090/api/v1/query?query=tikv_raftstore_region_count%7Btype%3D%22leader%22%7D'
    cmd1='curl http://'+pd+':9090/api/v1/query?query=tikv_grpc_msg_duration_seconds_count%7Btype%3D%22raw_put%22%7D&time='+sec
    cmd2='curl http://'+pd+':9090/api/v1/query?query=tikv_region_written_keys_sum&time='+sec
    cmd3='curl http://'+pd+':9090/api/v1/query?query=tikv_store_size_bytes%7Btype=%22available%22%7D'
    res1=os.popen(cmd1).read()
    dres1=json.loads(res1)
    nodes1=len(dres1['data']['result'])    #qps
    res2=os.popen(cmd2).read()
    dres2=json.loads(res2)
    nodes2=len(dres2['data']['result'])    #wps
    res3=os.popen(cmd3).read()
    dres3=json.loads(res3)
    nodes3=len(dres3['data']['result'])    #all nodes, in case of some node have qps==0 and not shown in grafana
    qps={}
    wps={}
    for i in range(nodes3):
        ip=dres1['data']['result'][i]['metric']['instance'].replace(':20180','')
        qps[ip]=0.0
        wps[ip]=0.0

    for i in range(nodes1):
        ip=dres1['data']['result'][i]['metric']['instance'].replace(':20180','')
        val=int(dres1['data']['result'][i]['value'][1])
        qps[ip]=val

    for i in range(nodes2):
        ip=dres2['data']['result'][i]['metric']['instance'].replace(':20180','')
        val=int(dres2['data']['result'][i]['value'][1])
        wps[ip]=val

    ips=list(qps.keys())

    maxcnt=0
    mincnt=wps[ips[0]]+qps[ips[0]]
    maxip=ips[0]
    minip=ips[0]
    for i in ips:
        cnt=qps[i]+wps[i]
        #print(qps[i], wps[i], cnt, i)
        if(cnt>maxcnt):
            maxcnt=cnt
            maxip=i
        if(cnt<mincnt):
            mincnt=cnt
            minip=i
    if(sw=='min'):
        print(minip)
    else:
        print(maxip)

if __name__ == "__main__":
    main(sys.argv)


