import os
import csv
import statistics
import matplotlib.pyplot as plt
import numpy as np
import seaborn as sns

def parseycsb1(fpath):
    ff=open(fpath,'r').read().split('\n')
    res={}
    for lines in ff:
        #print(lines)
        if('[OVERALL], Throughput' in lines):
            res['ops']=float(lines.split(', ')[2])
        if('[UPDATE], AverageLatency' in lines):
            res['avg']=float(lines.split(', ')[2])
        if('[UPDATE], 99thPercentileLatency' in lines):
            res['99']=float(lines.split(', ')[2])
        if('[UPDATE], 99.9PercentileLatency' in lines):    
            res['999']=float(lines.split(', ')[2])
        if('[UPDATE], MaxLatency' in lines):    
            res['max']=float(lines.split(', ')[2])
    return(res)

def parseycsb2(fpath):
    ff=open(fpath,'r').read().split('\n')
    line=ff[-2].split(', ')
    res={}
    # print(line)
    for rr in line:
        if('OPS' in rr):
            res['ops']=float(rr.split(': ')[1])
        if('Avg' in rr):
            res['avg']=float(rr.split(': ')[1])
        if('99th' in rr) and (not '99.99th' in rr):
            res['99']=float(rr.split(': ')[1])
        if('99.9th' in rr):
            res['999']=float(rr.split(': ')[1])
        if('Max' in rr):
            res['max']=float(rr.split(': ')[1])
    return(res)

def calcforexp(expname, fpath, dbname):
    if('noslow' in expname):
        expname=''
    flist=os.listdir(fpath)
    tmpres={'ops': [], 'avg': [], '99': [], '999': [], 'max': []}
    totres={'ops': 0.0, 'avg': 0.0, '99': 0.0, '999': 0.0, 'max': 0.0}
    listres={}
    cnt=0
    for _fp in flist:
        if(expname in _fp):
            cnt+=1
            fp=os.path.join(fpath, _fp)
            if(dbname=='tidb'):
                res=parseycsb2(fp)
            else:
                res=parseycsb1(fp)
            # print(fp, res)
            listres[fp]=res
            for kk in totres.keys():
                tmpres[kk].append(res[kk])
                #totres[kk]+=res[kk]
    for kk in totres.keys():
        #totres[kk]/=cnt
        if kk in ['99', '999', 'max']:
            totres[kk]=statistics.median(tmpres[kk])
        else:
            totres[kk]=sum(tmpres[kk]) / len(tmpres[kk]) 
    return(totres, listres)

def compareres(expname, noslowpath, slowpath, dbname):
    noslowres, _ =calcforexp('', noslowpath, dbname)
    slowres, _ =calcforexp(expname, slowpath, dbname)
    res={'ops': 0.0, 'avg': 0.0, '99': 0.0, '999': 0.0, 'max': 0.0}
    res['ops']=(slowres['ops']-noslowres['ops'])/noslowres['ops']*100
    res['avg']=(slowres['avg']-noslowres['avg'])/noslowres['avg']*100
    res['99']=(slowres['99']-noslowres['99'])/noslowres['99']*100
    res['999']=(slowres['999']-noslowres['999'])/noslowres['999']*100
    res['max']=(slowres['max']-noslowres['max'])/noslowres['max']*100
    return(res)

def exportcsv(_csv, dbtype):
    for exp in _csv:
        csvdata={'ops': {}, 'avg': {}, '99': {}, '999': {}, 'max': {}}
        csvname=exp['name']
        fname=csvname+'.csv'
        f=open(fname, 'w', newline='')
        for it in exp['data']:
            for ck in csvdata.keys():
                csvdata[ck][it[0]]=[]
            _, reslist =calcforexp(it[0], it[1], dbtype)
            for testcase in sorted(reslist.keys()):
                testres=reslist[testcase]
                # print(testcase, testres)
                for tk in testres.keys():
                    csvdata[tk][it[0]].append(testres[tk])
        for ck in csvdata.keys():
            f.write(ck+', \n')
            for header in csvdata[ck]:
                f.write(header+', ')
                for dat in csvdata[ck][header]:
                    f.write(str(dat)+', ')
                f.write('\n')
        f.close()

def getpercentage(_explist, dbtype, _spectype=None):
    resdict={}
    for exp in _explist:
        if(exp[0]=='---'):
            print('----------------------------------------------')
        else:
            tt=compareres(exp[0], exp[1], exp[2], dbtype)
            if(_spectype!=None and _spectype in exp[2]):
                resdict[exp[0]]=tt
            if(_spectype==None):
                print(exp)
                print("percentage: ", tt)
                print("")
    return(resdict)

# define experiments here, like [ exp1/exp2/exp5/exp6, folder for noslow result, folder for experiment result ]

tidb_explist=[
    # leaderhigh slowness
    ['---'],
    ['exp1','./1client_tmpfs/tidb/tidb_noslow1_swapoff_mem_results','./1client_tmpfs/tidb/tidb_leaderhigh_swapoff_mem_1_results'],
    ['exp2','./1client_tmpfs/tidb/tidb_noslow1_swapoff_mem_results','./1client_tmpfs/tidb/tidb_leaderhigh_swapoff_mem_1_results'],
    ['exp5','./1client_tmpfs/tidb/tidb_noslow1_swapoff_mem_results','./1client_tmpfs/tidb/tidb_leaderhigh_swapoff_mem_1_results'],
    ['exp6','./1client_tmpfs/tidb/tidb_noslow1_swapon_mem_results','./1client_tmpfs/tidb/tidb_leaderhigh_swapon_mem_1_results'],
    # leaderlow slowness
    ['---'],
    ['exp1','./1client_tmpfs/tidb/tidb_noslow1_swapoff_mem_results','./1client_tmpfs/tidb/tidb_leaderlow_swapoff_mem_results'],
    ['exp2','./1client_tmpfs/tidb/tidb_noslow1_swapoff_mem_results','./1client_tmpfs/tidb/tidb_leaderlow_swapoff_mem_results'],
    ['exp5','./1client_tmpfs/tidb/tidb_noslow1_swapoff_mem_results','./1client_tmpfs/tidb/tidb_leaderlow_swapoff_mem_results'],
    ['exp6','./1client_tmpfs/tidb/tidb_noslow1_swapon_mem_results','./1client_tmpfs/tidb/tidb_leaderlow_swapon_mem_results'],
    # leaderhigh slowness ssd
    ['---'],
    ['exp1','./1client_ssd/tidb/tidb_noslow1_swapoff_hdd_1_results','./1client_ssd/tidb/tidb_leaderhigh_swapoff_hdd_1_results'],
    ['exp2','./1client_ssd/tidb/tidb_noslow1_swapoff_hdd_1_results','./1client_ssd/tidb/tidb_leaderhigh_swapoff_hdd_1_results'],
    ['exp3','./1client_ssd/tidb/tidb_noslow1_swapoff_hdd_1_results','./1client_ssd/tidb/tidb_leaderhigh_swapoff_hdd_1_results'],
    ['exp4','./1client_ssd/tidb/tidb_noslow1_swapoff_hdd_1_results','./1client_ssd/tidb/tidb_leaderhigh_swapoff_hdd_1_results'],
    ['exp5','./1client_ssd/tidb/tidb_noslow1_swapoff_hdd_1_results','./1client_ssd/tidb/tidb_leaderhigh_swapoff_hdd_1_results'],
    # leaderlow slowness ssd
    ['---'],
    ['exp1','./1client_ssd/tidb/tidb_noslow1_swapoff_hdd_1_results','./1client_ssd/tidb/tidb_leaderlow_swapoff_hdd_1_results'],
    ['exp2','./1client_ssd/tidb/tidb_noslow1_swapoff_hdd_1_results','./1client_ssd/tidb/tidb_leaderlow_swapoff_hdd_1_results'],
    ['exp3','./1client_ssd/tidb/tidb_noslow1_swapoff_hdd_1_results','./1client_ssd/tidb/tidb_leaderlow_swapoff_hdd_1_results'],
    ['exp4','./1client_ssd/tidb/tidb_noslow1_swapoff_hdd_1_results','./1client_ssd/tidb/tidb_leaderlow_swapoff_hdd_1_results'],
    ['exp5','./1client_ssd/tidb/tidb_noslow1_swapoff_hdd_1_results','./1client_ssd/tidb/tidb_leaderlow_swapoff_hdd_1_results'],
    # follower slowness ssd
    ['---'],
    ['exp1','./1client_ssd/tidb/tidb_noslow2_swapoff_hdd_1_results','./1client_ssd/tidb/tidb_follower_swapoff_hdd_1_results'],
    ['exp2','./1client_ssd/tidb/tidb_noslow2_swapoff_hdd_1_results','./1client_ssd/tidb/tidb_follower_swapoff_hdd_1_results'],
    ['exp3','./1client_ssd/tidb/tidb_noslow2_swapoff_hdd_1_results','./1client_ssd/tidb/tidb_follower_swapoff_hdd_1_results'],
    ['exp4','./1client_ssd/tidb/tidb_noslow2_swapoff_hdd_1_results','./1client_ssd/tidb/tidb_follower_swapoff_hdd_1_results'],
    ['exp5','./1client_ssd/tidb/tidb_noslow2_swapoff_hdd_1_results','./1client_ssd/tidb/tidb_follower_swapoff_hdd_1_results'],
]

tidb_s_explist=[
    # leaderhigh slowness
    ['---'],
    ['exp1','./saturate_tmpfs/tidb/tidb_noslow1_swapoff_mem_results','./saturate_tmpfs/tidb/tidb_leaderhigh_swapoff_mem_results'],
    ['exp2','./saturate_tmpfs/tidb/tidb_noslow1_swapoff_mem_results','./saturate_tmpfs/tidb/tidb_leaderhigh_swapoff_mem_results'],
    ['exp5','./saturate_tmpfs/tidb/tidb_noslow1_swapoff_mem_results','./saturate_tmpfs/tidb/tidb_leaderhigh_swapoff_mem_results'],
    ['exp6','./saturate_tmpfs/tidb/tidb_noslow1_swapon_mem_results','./saturate_tmpfs/tidb/tidb_leaderhigh_swapon_mem_results'],
    # leaderlow slowness
    ['---'],
    ['exp1','./saturate_tmpfs/tidb/tidb_noslow1_swapoff_mem_results','./saturate_tmpfs/tidb/tidb_leaderlow_swapoff_mem_results'],
    ['exp2','./saturate_tmpfs/tidb/tidb_noslow1_swapoff_mem_results','./saturate_tmpfs/tidb/tidb_leaderlow_swapoff_mem_results'],
    ['exp5','./saturate_tmpfs/tidb/tidb_noslow1_swapoff_mem_results','./saturate_tmpfs/tidb/tidb_leaderlow_swapoff_mem_results'],
    ['exp6','./saturate_tmpfs/tidb/tidb_noslow1_swapon_mem_results','./saturate_tmpfs/tidb/tidb_leaderlow_swapon_mem_results'],
    # leaderhigh slowness ssd
    ['---'],
    ['exp1','./saturate_ssd/tidb/tidb_noslow1_swapoff_hdd_512_results','./saturate_ssd/tidb/tidb_leaderhigh_swapoff_hdd_512_results'],
    ['exp2','./saturate_ssd/tidb/tidb_noslow1_swapoff_hdd_512_results','./saturate_ssd/tidb/tidb_leaderhigh_swapoff_hdd_512_results'],
    ['exp3','./saturate_ssd/tidb/tidb_noslow1_swapoff_hdd_512_results','./saturate_ssd/tidb/tidb_leaderhigh_swapoff_hdd_512_results'],
    ['exp4','./saturate_ssd/tidb/tidb_noslow1_swapoff_hdd_512_results','./saturate_ssd/tidb/tidb_leaderhigh_swapoff_hdd_512_results'],
    ['exp5','./saturate_ssd/tidb/tidb_noslow1_swapoff_hdd_512_results','./saturate_ssd/tidb/tidb_leaderhigh_swapoff_hdd_512_results'],
    # leaderlow slowness ssd
    ['---'],
    ['exp1','./saturate_ssd/tidb/tidb_noslow1_swapoff_hdd_512_results','./saturate_ssd/tidb/tidb_leaderlow_swapoff_hdd_512_results'],
    ['exp2','./saturate_ssd/tidb/tidb_noslow1_swapoff_hdd_512_results','./saturate_ssd/tidb/tidb_leaderlow_swapoff_hdd_512_results'],
    ['exp3','./saturate_ssd/tidb/tidb_noslow1_swapoff_hdd_512_results','./saturate_ssd/tidb/tidb_leaderlow_swapoff_hdd_512_results'],
    ['exp4','./saturate_ssd/tidb/tidb_noslow1_swapoff_hdd_512_results','./saturate_ssd/tidb/tidb_leaderlow_swapoff_hdd_512_results'],
    ['exp5','./saturate_ssd/tidb/tidb_noslow1_swapoff_hdd_512_results','./saturate_ssd/tidb/tidb_leaderlow_swapoff_hdd_512_results'],
]


mongodb_explist=[
    # leader slowness
    ['---'],
    ['exp1','./1client_tmpfs/mongodb/mongodb_noslow_swapoff_mem_1_results','./1client_tmpfs/mongodb/mongodb_leader_swapoff_mem_1_results'],
    ['exp2','./1client_tmpfs/mongodb/mongodb_noslow_swapoff_mem_1_results','./1client_tmpfs/mongodb/mongodb_leader_swapoff_mem_1_results'],
    ['exp5','./1client_tmpfs/mongodb/mongodb_noslow_swapoff_mem_1_results','./1client_tmpfs/mongodb/mongodb_leader_swapoff_mem_1_results'],
    ['exp6','./1client_tmpfs/mongodb/mongodb_noslow_swapon_mem_1_results','./1client_tmpfs/mongodb/mongodb_leader_swapon_mem_1_results'],
    # follower slowness
    ['---'],
    ['exp1','./1client_tmpfs/mongodb/mongodb_noslow_swapoff_mem_1_results','./1client_tmpfs/mongodb/mongodb_follower_swapoff_mem_1_results'],
    ['exp2','./1client_tmpfs/mongodb/mongodb_noslow_swapoff_mem_1_results','./1client_tmpfs/mongodb/mongodb_follower_swapoff_mem_1_results'],
    ['exp5','./1client_tmpfs/mongodb/mongodb_noslow_swapoff_mem_1_results','./1client_tmpfs/mongodb/mongodb_follower_swapoff_mem_1_results'],
    ['exp6','./1client_tmpfs/mongodb/mongodb_noslow_swapon_mem_1_results','./1client_tmpfs/mongodb/mongodb_follower_swapon_mem_1_results'],
    # leader slowness hdd
    ['---'],
    ['exp1','./1client_ssd/mongodb/mongodb_noslow_swapoff_hdd_1_results','./1client_ssd/mongodb/mongodb_leader_swapoff_hdd_1_results'],
    ['exp2','./1client_ssd/mongodb/mongodb_noslow_swapoff_hdd_1_results','./1client_ssd/mongodb/mongodb_leader_swapoff_hdd_1_results'],
    ['exp3','./1client_ssd/mongodb/mongodb_noslow_swapoff_hdd_1_results','./1client_ssd/mongodb/mongodb_leader_swapoff_hdd_1_results'],
    ['exp4','./1client_ssd/mongodb/mongodb_noslow_swapoff_hdd_1_results','./1client_ssd/mongodb/mongodb_leader_swapoff_hdd_1_results'],
    ['exp5','./1client_ssd/mongodb/mongodb_noslow_swapoff_hdd_1_results','./1client_ssd/mongodb/mongodb_leader_swapoff_hdd_1_results'],
    # follower slowness hdd
    ['---'],
    ['exp1','./1client_ssd/mongodb/mongodb_noslow_swapoff_hdd_1_results','./1client_ssd/mongodb/mongodb_follower_swapoff_hdd_1_results'],
    ['exp2','./1client_ssd/mongodb/mongodb_noslow_swapoff_hdd_1_results','./1client_ssd/mongodb/mongodb_follower_swapoff_hdd_1_results'],
    ['exp3','./1client_ssd/mongodb/mongodb_noslow_swapoff_hdd_1_results','./1client_ssd/mongodb/mongodb_follower_swapoff_hdd_1_results'],
    ['exp4','./1client_ssd/mongodb/mongodb_noslow_swapoff_hdd_1_results','./1client_ssd/mongodb/mongodb_follower_swapoff_hdd_1_results'],
    ['exp5','./1client_ssd/mongodb/mongodb_noslow_swapoff_hdd_1_results','./1client_ssd/mongodb/mongodb_follower_swapoff_hdd_1_results'],
]

mongodb_s_explist=[
    # leader slowness
    ['---'],
    ['exp1','./saturate_tmpfs/mongodb/mongodb_noslow_swapoff_mem_32_results','./saturate_tmpfs/mongodb/mongodb_leader_swapoff_mem_32_results'],
    ['exp2','./saturate_tmpfs/mongodb/mongodb_noslow_swapoff_mem_32_results','./saturate_tmpfs/mongodb/mongodb_leader_swapoff_mem_32_results'],
    ['exp5','./saturate_tmpfs/mongodb/mongodb_noslow_swapoff_mem_32_results','./saturate_tmpfs/mongodb/mongodb_leader_swapoff_mem_32_results'],
    ['exp6','./saturate_tmpfs/mongodb/mongodb_noslow_swapon_mem_32_results','./saturate_tmpfs/mongodb/mongodb_leader_swapon_mem_32_results'],
    # follower slowness
    ['---'],
    ['exp1','./saturate_tmpfs/mongodb/mongodb_noslow_swapoff_mem_32_results','./saturate_tmpfs/mongodb/mongodb_follower_swapoff_mem_32_results'],
    ['exp2','./saturate_tmpfs/mongodb/mongodb_noslow_swapoff_mem_32_results','./saturate_tmpfs/mongodb/mongodb_follower_swapoff_mem_32_results'],
    ['exp5','./saturate_tmpfs/mongodb/mongodb_noslow_swapoff_mem_32_results','./saturate_tmpfs/mongodb/mongodb_follower_swapoff_mem_32_results'],
    ['exp6','./saturate_tmpfs/mongodb/mongodb_noslow_swapon_mem_32_results','./saturate_tmpfs/mongodb/mongodb_follower_swapon_mem_32_results'],
    # leader slowness hdd
    ['---'],
    ['exp1','./saturate_ssd/mongodb/mongodb_noslow_swapoff_hdd_320_results','./saturate_ssd/mongodb/mongodb_leader_swapoff_hdd_320_results'],
    ['exp2','./saturate_ssd/mongodb/mongodb_noslow_swapoff_hdd_320_results','./saturate_ssd/mongodb/mongodb_leader_swapoff_hdd_320_results'],
    ['exp3','./saturate_ssd/mongodb/mongodb_noslow_swapoff_hdd_320_results','./saturate_ssd/mongodb/mongodb_leader_swapoff_hdd_320_results'],
    ['exp4','./saturate_ssd/mongodb/mongodb_noslow_swapoff_hdd_320_results','./saturate_ssd/mongodb/mongodb_leader_swapoff_hdd_320_results'],
    ['exp5','./saturate_ssd/mongodb/mongodb_noslow_swapoff_hdd_320_results','./saturate_ssd/mongodb/mongodb_leader_swapoff_hdd_320_results'],
    # follower slowness hdd
    ['---'],
    ['exp1','./saturate_ssd/mongodb/mongodb_noslow_swapoff_hdd_320_results','./saturate_ssd/mongodb/mongodb_follower_swapoff_hdd_320_results'],
    ['exp2','./saturate_ssd/mongodb/mongodb_noslow_swapoff_hdd_320_results','./saturate_ssd/mongodb/mongodb_follower_swapoff_hdd_320_results'],
    ['exp3','./saturate_ssd/mongodb/mongodb_noslow_swapoff_hdd_320_results','./saturate_ssd/mongodb/mongodb_follower_swapoff_hdd_320_results'],
    ['exp4','./saturate_ssd/mongodb/mongodb_noslow_swapoff_hdd_320_results','./saturate_ssd/mongodb/mongodb_follower_swapoff_hdd_320_results'],
    ['exp5','./saturate_ssd/mongodb/mongodb_noslow_swapoff_hdd_320_results','./saturate_ssd/mongodb/mongodb_follower_swapoff_hdd_320_results'],
]


rethinkdb_explist=[
    # leader slowness
    ['---'],
    ['exp1','./1client_tmpfs/rethinkdb/noslow_swapoff','./1client_tmpfs/rethinkdb/leader'],
    ['exp2','./1client_tmpfs/rethinkdb/noslow_swapoff','./1client_tmpfs/rethinkdb/leader'],
    ['exp5','./1client_tmpfs/rethinkdb/noslow_swapoff','./1client_tmpfs/rethinkdb/leader'],
    ['exp6','./1client_tmpfs/rethinkdb/noslow_swapon','./1client_tmpfs/rethinkdb/rethinkdb_leader_memory_swapon_results'],

    # follower slowness
    ['---'],
    ['exp5','./1client_tmpfs/rethinkdb/rethinkdb_noslow_memory_swapoff_results','./1client_tmpfs/rethinkdb/rethinkdb_follower_memory_swapoff_results'],
    ['exp6','./1client_tmpfs/rethinkdb/rethinkdb_noslow_memory_swapon_results','./1client_tmpfs/rethinkdb/rethinkdb_follower_memory_swapon_results'],

    # leader slowness ssd
    ['---'],
    # leader slowness
    ['exp1','./1client_ssd/rethinkdb/rethinkdb_noslow_disk_swapoff_results','./1client_ssd/rethinkdb/rethinkdb_leader_disk_swapoff_results'],
    ['exp2','./1client_ssd/rethinkdb/rethinkdb_noslow_disk_swapoff_results','./1client_ssd/rethinkdb/rethinkdb_leader_disk_swapoff_results'],
    ['exp3','./1client_ssd/rethinkdb/rethinkdb_noslow_disk_swapoff_results','./1client_ssd/rethinkdb/rethinkdb_leader_disk_swapoff_results'],
    ['exp4','./1client_ssd/rethinkdb/rethinkdb_noslow_disk_swapoff_results','./1client_ssd/rethinkdb/rethinkdb_leader_disk_swapoff_results'],
    ['exp5','./1client_ssd/rethinkdb/rethinkdb_noslow_disk_swapoff_results','./1client_ssd/rethinkdb/rethinkdb_leader_disk_swapoff_results'],

    # follower slowness ssd
    ['---'],
    ['exp1','./1client_ssd/rethinkdb/rethinkdb_noslow_disk_swapoff_results','./1client_ssd/rethinkdb/rethinkdb_follower_disk_swapoff_results'],
    ['exp2','./1client_ssd/rethinkdb/rethinkdb_noslow_disk_swapoff_results','./1client_ssd/rethinkdb/rethinkdb_follower_disk_swapoff_results'],
    ['exp3','./1client_ssd/rethinkdb/rethinkdb_noslow_disk_swapoff_results','./1client_ssd/rethinkdb/rethinkdb_follower_disk_swapoff_results'],
    ['exp4','./1client_ssd/rethinkdb/rethinkdb_noslow_disk_swapoff_results','./1client_ssd/rethinkdb/rethinkdb_follower_disk_swapoff_results'],
    ['exp5','./1client_ssd/rethinkdb/rethinkdb_noslow_disk_swapoff_results','./1client_ssd/rethinkdb/rethinkdb_follower_disk_swapoff_results'],
]

rethinkdb_s_explist=[
    # leader slowness
    ['---'],
    ['exp1','./saturate_tmpfs/rethinkdb/rethinkdb_noslow_memory_swapoff_results','./saturate_tmpfs/rethinkdb/rethinkdb_leader_memory_swapoff_results'],
    ['exp2','./saturate_tmpfs/rethinkdb/rethinkdb_noslow_memory_swapoff_results','./saturate_tmpfs/rethinkdb/rethinkdb_leader_memory_swapoff_results'],
    ['exp5','./saturate_tmpfs/rethinkdb/rethinkdb_noslow_memory_swapoff_results','./saturate_tmpfs/rethinkdb/rethinkdb_leader_memory_swapoff_results'],
    ['exp6','./saturate_tmpfs/rethinkdb/rethinkdb_noslow_memory_swapon_results','./saturate_tmpfs/rethinkdb/rethinkdb_leader_memory_swapon_results'],

    # follower slowness
    ['---'],
    ['exp5','./saturate_tmpfs/rethinkdb/rethinkdb_noslow_memory_swapoff_results','./saturate_tmpfs/rethinkdb/rethinkdb_follower_memory_swapoff_results'],
    ['exp6','./saturate_tmpfs/rethinkdb/rethinkdb_noslow_memory_swapon_results','./saturate_tmpfs/rethinkdb/rethinkdb_follower_memory_swapon_results'],

    # leader slowness ssd
    ['---'],
    ['exp1','./saturate_ssd/rethinkdb/rethinkdb_noslow_disk_swapoff_results','./saturate_ssd/rethinkdb/rethinkdb_leader_disk_swapoff_results'],
    ['exp2','./saturate_ssd/rethinkdb/rethinkdb_noslow_disk_swapoff_results','./saturate_ssd/rethinkdb/rethinkdb_leader_disk_swapoff_results'],
    ['exp3','./saturate_ssd/rethinkdb/rethinkdb_noslow_disk_swapoff_results','./saturate_ssd/rethinkdb/rethinkdb_leader_disk_swapoff_results'],
    ['exp4','./saturate_ssd/rethinkdb/rethinkdb_noslow_disk_swapoff_results','./saturate_ssd/rethinkdb/rethinkdb_leader_disk_swapoff_results'],
    ['exp5','./saturate_ssd/rethinkdb/rethinkdb_noslow_disk_swapoff_results','./saturate_ssd/rethinkdb/rethinkdb_leader_disk_swapoff_results'],

    # follower slowness ssd
    ['---'],
    ['exp1','./saturate_ssd/rethinkdb/rethinkdb_noslow_disk_swapoff_results','./saturate_ssd/rethinkdb/rethinkdb_follower_disk_swapoff_results'],
    ['exp2','./saturate_ssd/rethinkdb/rethinkdb_noslow_disk_swapoff_results','./saturate_ssd/rethinkdb/rethinkdb_follower_disk_swapoff_results'],
    ['exp3','./saturate_ssd/rethinkdb/rethinkdb_noslow_disk_swapoff_results','./saturate_ssd/rethinkdb/rethinkdb_follower_disk_swapoff_results'],
    ['exp4','./saturate_ssd/rethinkdb/rethinkdb_noslow_disk_swapoff_results','./saturate_ssd/rethinkdb/rethinkdb_follower_disk_swapoff_results'],
    ['exp5','./saturate_ssd/rethinkdb/rethinkdb_noslow_disk_swapoff_results','./saturate_ssd/rethinkdb/rethinkdb_follower_disk_swapoff_results'],
]

# Final CRDB 1 client list
cockroachdb_explist=[
    # leaderhigh slowness
    ['---'],
    ['exp1','./1client_tmpfs/cockroachdb/noslow_maxthroughput','./1client_tmpfs/cockroachdb/maxthroughput'],
    ['exp2','./1client_tmpfs/cockroachdb/noslow_maxthroughput','./1client_tmpfs/cockroachdb/maxthroughput'],
    ['exp5','./1client_tmpfs/cockroachdb/noslow_maxthroughput','./1client_tmpfs/cockroachdb/maxthroughput'],
    ['exp6','./1client_tmpfs/cockroachdb/cockroachdb_noslowmaxthroughput_memory_swapon_results','./1client_tmpfs/cockroachdb/cockroachdb_maxthroughput_memory_swapon_results'],
   
    # leaderlow slowness
    ['---'],
    ['exp1','./1client_tmpfs/cockroachdb/cockroachdb_noslowminthroughput_memory_swapoff_results','./1client_tmpfs/cockroachdb/cockroachdb_minthroughput_memory_swapoff_results'],
    ['exp2','./1client_tmpfs/cockroachdb/cockroachdb_noslowminthroughput_memory_swapoff_results','./1client_tmpfs/cockroachdb/cockroachdb_minthroughput_memory_swapoff_results'],
    ['exp5','./1client_tmpfs/cockroachdb/cockroachdb_noslowminthroughput_memory_swapoff_results','./1client_tmpfs/cockroachdb/cockroachdb_minthroughput_memory_swapoff_results'],
    ['exp6','./1client_tmpfs/cockroachdb/cockroachdb_noslowminthroughput_memory_swapon_results','./1client_tmpfs/cockroachdb/cockroachdb_minthroughput_memory_swapon_results'],
    
    # leaderhigh slowness ssd
    ['---'],
    ['exp1','./1client_ssd/cockroachdb/cockroachdb_noslowmaxthroughput_disk_swapoff_results','./1client_ssd/cockroachdb/cockroachdb_maxthroughput_disk_swapoff_results'],
    ['exp2','./1client_ssd/cockroachdb/cockroachdb_noslowmaxthroughput_disk_swapoff_results','./1client_ssd/cockroachdb/cockroachdb_maxthroughput_disk_swapoff_results'],
    ['exp3','./1client_ssd/cockroachdb/cockroachdb_noslowmaxthroughput_disk_swapoff_results','./1client_ssd/cockroachdb/cockroachdb_maxthroughput_disk_swapoff_results'],
    ['exp4','./1client_ssd/cockroachdb/cockroachdb_noslowmaxthroughput_disk_swapoff_results','./1client_ssd/cockroachdb/cockroachdb_maxthroughput_disk_swapoff_results'],
    ['exp5','./1client_ssd/cockroachdb/cockroachdb_noslowmaxthroughput_disk_swapoff_results','./1client_ssd/cockroachdb/cockroachdb_maxthroughput_disk_swapoff_results'],
    
    # leaderlow slowness ssd
    ['---'],
    ['exp1','./1client_ssd/cockroachdb/cockroachdb_noslowminthroughput_disk_swapoff_results','./1client_ssd/cockroachdb/cockroachdb_minthroughput_disk_swapoff_results'],
    ['exp2','./1client_ssd/cockroachdb/cockroachdb_noslowminthroughput_disk_swapoff_results','./1client_ssd/cockroachdb/cockroachdb_minthroughput_disk_swapoff_results'],
    ['exp3','./1client_ssd/cockroachdb/cockroachdb_noslowminthroughput_disk_swapoff_results','./1client_ssd/cockroachdb/cockroachdb_minthroughput_disk_swapoff_results'],
    ['exp4','./1client_ssd/cockroachdb/cockroachdb_noslowminthroughput_disk_swapoff_results','./1client_ssd/cockroachdb/cockroachdb_minthroughput_disk_swapoff_results'],
    ['exp5','./1client_ssd/cockroachdb/cockroachdb_noslowminthroughput_disk_swapoff_results','./1client_ssd/cockroachdb/cockroachdb_minthroughput_disk_swapoff_results'],
]

# Final CRDB Saturate results
cockroachdb_s_explist=[
    # leaderhigh slowness
    ['---'],
    ['exp1','./saturate_tmpfs/cockroachdb/cockroachdb_noslowmaxthroughput_memory_swapoff_results','./saturate_tmpfs/cockroachdb/cockroachdb_maxthroughput_memory_swapoff_results'],
    ['exp2','./saturate_tmpfs/cockroachdb/cockroachdb_noslowmaxthroughput_memory_swapoff_results','./saturate_tmpfs/cockroachdb/cockroachdb_maxthroughput_memory_swapoff_results'],
    ['exp5','./saturate_tmpfs/cockroachdb/cockroachdb_noslowmaxthroughput_memory_swapoff_results','./saturate_tmpfs/cockroachdb/cockroachdb_maxthroughput_memory_swapoff_results'],
    ['exp6','./saturate_tmpfs/cockroachdb/cockroachdb_noslowmaxthroughput_memory_swapon_results','./saturate_tmpfs/cockroachdb/cockroachdb_maxthroughput_memory_swapon_results'],

    # leaderlow slowness
    ['---'],
    ['exp1','./saturate_tmpfs/cockroachdb/cockroachdb_noslowminthroughput_memory_swapoff_results','./saturate_tmpfs/cockroachdb/cockroachdb_minthroughput_memory_swapoff_results'],
    ['exp2','./saturate_tmpfs/cockroachdb/cockroachdb_noslowminthroughput_memory_swapoff_results','./saturate_tmpfs/cockroachdb/cockroachdb_minthroughput_memory_swapoff_results'],
    ['exp5','./saturate_tmpfs/cockroachdb/cockroachdb_noslowminthroughput_memory_swapoff_results','./saturate_tmpfs/cockroachdb/cockroachdb_minthroughput_memory_swapoff_results'],
    ['exp6','./saturate_tmpfs/cockroachdb/cockroachdb_noslowminthroughput_memory_swapon_results','./saturate_tmpfs/cockroachdb/cockroachdb_minthroughput_memory_swapon_results'],

    # leaderhigh slowness ssd
    ['---'],
    ['exp1','./saturate_ssd/cockroachdb/cockroachdb_noslowmaxthroughput_disk_swapoff_results','./saturate_ssd/cockroachdb/cockroachdb_maxthroughput_disk_swapoff_results'],
    ['exp2','./saturate_ssd/cockroachdb/cockroachdb_noslowmaxthroughput_disk_swapoff_results','./saturate_ssd/cockroachdb/cockroachdb_maxthroughput_disk_swapoff_results'],
    ['exp3','./saturate_ssd/cockroachdb/cockroachdb_noslowmaxthroughput_disk_swapoff_results','./saturate_ssd/cockroachdb/cockroachdb_maxthroughput_disk_swapoff_results'],
    ['exp4','./saturate_ssd/cockroachdb/cockroachdb_noslowmaxthroughput_disk_swapoff_results','./saturate_ssd/cockroachdb/cockroachdb_maxthroughput_disk_swapoff_results'],
    ['exp5','./saturate_ssd/cockroachdb/cockroachdb_noslowmaxthroughput_disk_swapoff_results','./saturate_ssd/cockroachdb/cockroachdb_maxthroughput_disk_swapoff_results'],
    
    # leaderlow slowness ssd
    ['---'],
    ['exp1','./saturate_ssd/cockroachdb/cockroachdb_noslowminthroughput_disk_swapoff_results','./saturate_ssd/cockroachdb/cockroachdb_minthroughput_disk_swapoff_results'],
    ['exp2','./saturate_ssd/cockroachdb/cockroachdb_noslowminthroughput_disk_swapoff_results','./saturate_ssd/cockroachdb/cockroachdb_minthroughput_disk_swapoff_results'],
    ['exp3','./saturate_ssd/cockroachdb/cockroachdb_noslowminthroughput_disk_swapoff_results','./saturate_ssd/cockroachdb/cockroachdb_minthroughput_disk_swapoff_results'],
    ['exp4','./saturate_ssd/cockroachdb/cockroachdb_noslowminthroughput_disk_swapoff_results','./saturate_ssd/cockroachdb/cockroachdb_minthroughput_disk_swapoff_results'],
    ['exp5','./saturate_ssd/cockroachdb/cockroachdb_noslowminthroughput_disk_swapoff_results','./saturate_ssd/cockroachdb/cockroachdb_minthroughput_disk_swapoff_results'],
]

# define experiments in csv file here

tidb_csv=[
    {
        'name': 'tidb_leaderhigh',
        'data': [
                    ['noslow1_swapoff', './1client_tmpfs/tidb/tidb_noslow1_swapoff_mem_results'],
                    ['exp1', './1client_tmpfs/tidb/tidb_leaderhigh_swapoff_mem_1_results'],
                    ['exp2', './1client_tmpfs/tidb/tidb_leaderhigh_swapoff_mem_1_results'],
                    ['exp5', './1client_tmpfs/tidb/tidb_leaderhigh_swapoff_mem_1_results'],
                    ['exp6', './1client_tmpfs/tidb/tidb_leaderhigh_swapon_mem_1_results'],
                    ['noslow1_swapon', './1client_tmpfs/tidb/tidb_noslow1_swapon_mem_results']
                ]
    },
    {
        'name': 'tidb_leaderlow',
        'data': [
                    ['noslow1_swapoff', './1client_tmpfs/tidb/tidb_noslow1_swapoff_mem_results'],
                    ['exp1', './1client_tmpfs/tidb/tidb_leaderlow_swapoff_mem_results'],
                    ['exp2', './1client_tmpfs/tidb/tidb_leaderlow_swapoff_mem_results'],
                    ['exp5', './1client_tmpfs/tidb/tidb_leaderlow_swapoff_mem_results'],
                    ['exp6', './1client_tmpfs/tidb/tidb_leaderlow_swapon_mem_results'],
                    ['noslow1_swapon', './1client_tmpfs/tidb/tidb_noslow1_swapon_mem_results']
                ]
    },
    {
        'name': 'tidb_leaderhigh_ssd',
        'data': [
                    ['noslow1_swapoff', './1client_ssd/tidb/tidb_noslow1_swapoff_hdd_1_results'],
                    ['exp1', './1client_ssd/tidb/tidb_leaderhigh_swapoff_hdd_1_results'],
                    ['exp2', './1client_ssd/tidb/tidb_leaderhigh_swapoff_hdd_1_results'],
                    ['exp3', './1client_ssd/tidb/tidb_leaderhigh_swapoff_hdd_1_results'],
                    ['exp4', './1client_ssd/tidb/tidb_leaderhigh_swapoff_hdd_1_results'],
                    ['exp5', './1client_ssd/tidb/tidb_leaderhigh_swapoff_hdd_1_results'],
                ]
    },
    {
        'name': 'tidb_leaderlow_ssd',
        'data': [
                    ['noslow1_swapoff', './1client_ssd/tidb/tidb_noslow1_swapoff_hdd_1_results'],
                    ['exp1', './1client_ssd/tidb/tidb_leaderlow_swapoff_hdd_1_results'],
                    ['exp2', './1client_ssd/tidb/tidb_leaderlow_swapoff_hdd_1_results'],
                    ['exp3', './1client_ssd/tidb/tidb_leaderlow_swapoff_hdd_1_results'],
                    ['exp4', './1client_ssd/tidb/tidb_leaderlow_swapoff_hdd_1_results'],
                    ['exp5', './1client_ssd/tidb/tidb_leaderlow_swapoff_hdd_1_results'],
                ]
    },
    {
        'name': 'tidb_follower_ssd',
        'data': [
                    ['noslow1_swapoff', './1client_ssd/tidb/tidb_noslow2_swapoff_hdd_1_results'],
                    ['exp1', './1client_ssd/tidb/tidb_follower_swapoff_hdd_1_results'],
                    ['exp2', './1client_ssd/tidb/tidb_follower_swapoff_hdd_1_results'],
                    ['exp3', './1client_ssd/tidb/tidb_follower_swapoff_hdd_1_results'],
                    ['exp4', './1client_ssd/tidb/tidb_follower_swapoff_hdd_1_results'],
                    ['exp5', './1client_ssd/tidb/tidb_follower_swapoff_hdd_1_results'],
                ]
    },
]

tidb_s_csv=[
    {
        'name': 'tidb_saturate_leaderhigh',
        'data': [
                    ['noslow1_swapoff', './saturate_tmpfs/tidb/tidb_noslow1_swapoff_mem_results'],
                    ['exp1', './saturate_tmpfs/tidb/tidb_leaderhigh_swapoff_mem_results'],
                    ['exp2', './saturate_tmpfs/tidb/tidb_leaderhigh_swapoff_mem_results'],
                    ['exp5', './saturate_tmpfs/tidb/tidb_leaderhigh_swapoff_mem_results'],
                    ['exp6', './saturate_tmpfs/tidb/tidb_leaderhigh_swapon_mem_results'],
                    ['noslow1_swapon', './saturate_tmpfs/tidb/tidb_noslow1_swapon_mem_results']
                ]
    },
    {
        'name': 'tidb_saturate_leaderlow',
        'data': [
                    ['noslow1_swapoff', './saturate_tmpfs/tidb/tidb_noslow1_swapoff_mem_results'],
                    ['exp1', './saturate_tmpfs/tidb/tidb_leaderlow_swapoff_mem_results'],
                    ['exp2', './saturate_tmpfs/tidb/tidb_leaderlow_swapoff_mem_results'],
                    ['exp5', './saturate_tmpfs/tidb/tidb_leaderlow_swapoff_mem_results'],
                    ['exp6', './saturate_tmpfs/tidb/tidb_leaderlow_swapon_mem_results'],
                    ['noslow1_swapon', './saturate_tmpfs/tidb/tidb_noslow1_swapon_mem_results']
                ]
    },
    {
        'name': 'tidb_saturate_leaderhigh_ssd',
        'data': [
                    ['noslow1_swapoff', './saturate_ssd/tidb/tidb_noslow1_swapoff_hdd_512_results'],
                    ['exp1', './saturate_ssd/tidb/tidb_leaderhigh_swapoff_hdd_512_results'],
                    ['exp2', './saturate_ssd/tidb/tidb_leaderhigh_swapoff_hdd_512_results'],
                    ['exp3', './saturate_ssd/tidb/tidb_leaderhigh_swapoff_hdd_512_results'],
                    ['exp4', './saturate_ssd/tidb/tidb_leaderhigh_swapoff_hdd_512_results'],
                    ['exp5', './saturate_ssd/tidb/tidb_leaderhigh_swapoff_hdd_512_results'],
                ]
    },
    {
        'name': 'tidb_saturate_leaderlow_ssd',
        'data': [
                    ['noslow1_swapoff', './saturate_ssd/tidb/tidb_noslow1_swapoff_hdd_512_results'],
                    ['exp1', './saturate_ssd/tidb/tidb_leaderlow_swapoff_hdd_512_results'],
                    ['exp2', './saturate_ssd/tidb/tidb_leaderlow_swapoff_hdd_512_results'],
                    ['exp3', './saturate_ssd/tidb/tidb_leaderlow_swapoff_hdd_512_results'],
                    ['exp4', './saturate_ssd/tidb/tidb_leaderlow_swapoff_hdd_512_results'],
                    ['exp5', './saturate_ssd/tidb/tidb_leaderlow_swapoff_hdd_512_results'],
                ]
    },
]

mongo_csv=[
    {
        'name': 'mongodb_leader',
        'data': [
                    ['noslow_swapoff', './1client_tmpfs/mongodb/mongodb_noslow_swapoff_mem_1_results'],
                    ['exp1', './1client_tmpfs/mongodb/mongodb_leader_swapoff_mem_1_results'],
                    ['exp2', './1client_tmpfs/mongodb/mongodb_leader_swapoff_mem_1_results'],
                    ['exp5', './1client_tmpfs/mongodb/mongodb_leader_swapoff_mem_1_results'],
                    ['exp6', './1client_tmpfs/mongodb/mongodb_leader_swapon_mem_1_results'],
                    ['noslow_swapon', './1client_tmpfs/mongodb/mongodb_noslow_swapon_mem_1_results']
                ]
    },
    {
        'name': 'mongodb_follower',
        'data': [
                    ['noslow_swapoff', './1client_tmpfs/mongodb/mongodb_noslow_swapoff_mem_1_results'],
                    ['exp1', './1client_tmpfs/mongodb/mongodb_follower_swapoff_mem_1_results'],
                    ['exp2', './1client_tmpfs/mongodb/mongodb_follower_swapoff_mem_1_results'],
                    ['exp5', './1client_tmpfs/mongodb/mongodb_follower_swapoff_mem_1_results'],
                    ['exp6', './1client_tmpfs/mongodb/mongodb_follower_swapon_mem_1_results'],
                    ['noslow_swapon', './1client_tmpfs/mongodb/mongodb_noslow_swapon_mem_1_results']
                ]
    },
    {
        'name': 'mongodb_leader_ssd',
        'data': [
                    ['noslow_swapoff', './1client_ssd/mongodb/mongodb_noslow_swapoff_hdd_1_results'],
                    ['exp1', './1client_ssd/mongodb/mongodb_leader_swapoff_hdd_1_results'],
                    ['exp2', './1client_ssd/mongodb/mongodb_leader_swapoff_hdd_1_results'],
                    ['exp3', './1client_ssd/mongodb/mongodb_leader_swapoff_hdd_1_results'],
                    ['exp4', './1client_ssd/mongodb/mongodb_leader_swapoff_hdd_1_results'],
                    ['exp5', './1client_ssd/mongodb/mongodb_leader_swapoff_hdd_1_results'],
                ]
    },
    {
        'name': 'mongodb_follower_ssd',
        'data': [
                    ['noslow_swapoff', './1client_ssd/mongodb/mongodb_noslow_swapoff_hdd_1_results'],
                    ['exp1', './1client_ssd/mongodb/mongodb_follower_swapoff_hdd_1_results'],
                    ['exp2', './1client_ssd/mongodb/mongodb_follower_swapoff_hdd_1_results'],
                    ['exp3', './1client_ssd/mongodb/mongodb_follower_swapoff_hdd_1_results'],
                    ['exp4', './1client_ssd/mongodb/mongodb_follower_swapoff_hdd_1_results'],
                    ['exp5', './1client_ssd/mongodb/mongodb_follower_swapoff_hdd_1_results'],
                ]
    },
]

mongo_s_csv=[
    {
        'name': 'mongodb_saturate_leader',
        'data': [
                    ['noslow_swapoff', './saturate_tmpfs/mongodb/mongodb_noslow_swapoff_mem_32_results'],
                    ['exp1', './saturate_tmpfs/mongodb/mongodb_leader_swapoff_mem_32_results'],
                    ['exp2', './saturate_tmpfs/mongodb/mongodb_leader_swapoff_mem_32_results'],
                    ['exp5', './saturate_tmpfs/mongodb/mongodb_leader_swapoff_mem_32_results'],
                    ['exp6', './saturate_tmpfs/mongodb/mongodb_leader_swapon_mem_32_results'],
                    ['noslow_swapon', './saturate_tmpfs/mongodb/mongodb_noslow_swapon_mem_32_results']
                ]
    },
    {
        'name': 'mongodb_saturate_follower',
        'data': [
                    ['noslow_swapoff', './saturate_tmpfs/mongodb/mongodb_noslow_swapoff_mem_32_results'],
                    ['exp1', './saturate_tmpfs/mongodb/mongodb_follower_swapoff_mem_32_results'],
                    ['exp2', './saturate_tmpfs/mongodb/mongodb_follower_swapoff_mem_32_results'],
                    ['exp5', './saturate_tmpfs/mongodb/mongodb_follower_swapoff_mem_32_results'],
                    ['exp6', './saturate_tmpfs/mongodb/mongodb_follower_swapon_mem_32_results'],
                    ['noslow_swapon', './saturate_tmpfs/mongodb/mongodb_noslow_swapon_mem_32_results']
                ]
    },
    {
        'name': 'mongodb_saturate_leader_ssd',
        'data': [
                    ['noslow_swapoff', './saturate_ssd/mongodb/mongodb_noslow_swapoff_hdd_320_results'],
                    ['exp1', './saturate_ssd/mongodb/mongodb_leader_swapoff_hdd_320_results'],
                    ['exp2', './saturate_ssd/mongodb/mongodb_leader_swapoff_hdd_320_results'],
                    ['exp3', './saturate_ssd/mongodb/mongodb_leader_swapoff_hdd_320_results'],
                    ['exp4', './saturate_ssd/mongodb/mongodb_leader_swapoff_hdd_320_results'],
                    ['exp5', './saturate_ssd/mongodb/mongodb_leader_swapoff_hdd_320_results'],
                ]
    },
    {
        'name': 'mongodb_saturate_follower_ssd',
        'data': [
                    ['noslow_swapoff', './saturate_ssd/mongodb/mongodb_noslow_swapoff_hdd_320_results'],
                    ['exp1', './saturate_ssd/mongodb/mongodb_follower_swapoff_hdd_320_results'],
                    ['exp2', './saturate_ssd/mongodb/mongodb_follower_swapoff_hdd_320_results'],
                    ['exp3', './saturate_ssd/mongodb/mongodb_follower_swapoff_hdd_320_results'],
                    ['exp4', './saturate_ssd/mongodb/mongodb_follower_swapoff_hdd_320_results'],
                    ['exp5', './saturate_ssd/mongodb/mongodb_follower_swapoff_hdd_320_results'],
                ]
    },
]

rethinkdb_csv=[
    {
        'name': 'rethinkdb_leader',
        'data': [
                    ['noslow_swapoff', './1client_tmpfs/rethinkdb/noslow_swapoff'],
                    ['exp1', './1client_tmpfs/rethinkdb/leader'],
                    ['exp2', './1client_tmpfs/rethinkdb/leader'],
                    ['exp5', './1client_tmpfs/rethinkdb/leader'],
                    ['exp6', './1client_tmpfs/rethinkdb/rethinkdb_leader_memory_swapon_results'],
                    ['noslow_swapon', './1client_tmpfs/rethinkdb/noslow_swapon']
                ]
    },
    {
    'name': 'rethinkdb_follower',
    'data': [
                ['noslow_swapoff', './1client_tmpfs/rethinkdb/rethinkdb_noslow_memory_swapoff_results'],
                ['exp5', './1client_tmpfs/rethinkdb/rethinkdb_follower_memory_swapoff_results'],
                ['exp6', './1client_tmpfs/rethinkdb/rethinkdb_follower_memory_swapon_results'],
                ['noslow_swapon', './1client_tmpfs/rethinkdb/rethinkdb_noslow_memory_swapon_results']
            ]
    },
    {
        'name': 'rethinkdb_leader_ssd',
        'data': [
                    ['noslow_swapoff', './1client_ssd/rethinkdb/rethinkdb_noslow_disk_swapoff_results'],
                    ['exp1', './1client_ssd/rethinkdb/rethinkdb_leader_disk_swapoff_results'],
                    ['exp2', './1client_ssd/rethinkdb/rethinkdb_leader_disk_swapoff_results'],
                    ['exp3', './1client_ssd/rethinkdb/rethinkdb_leader_disk_swapoff_results'],
                    ['exp4', './1client_ssd/rethinkdb/rethinkdb_leader_disk_swapoff_results'],
                    ['exp5', './1client_ssd/rethinkdb/rethinkdb_leader_disk_swapoff_results']
                ]
    },
    {
        'name': 'rethinkdb_follower_ssd',
        'data': [
                    ['noslow_swapoff', './1client_ssd/rethinkdb/rethinkdb_noslow_disk_swapoff_results'],
                    ['exp1', './1client_ssd/rethinkdb/rethinkdb_follower_disk_swapoff_results'],
                    ['exp2', './1client_ssd/rethinkdb/rethinkdb_follower_disk_swapoff_results'],
                    ['exp3', './1client_ssd/rethinkdb/rethinkdb_follower_disk_swapoff_results'],
                    ['exp4', './1client_ssd/rethinkdb/rethinkdb_follower_disk_swapoff_results'],
                    ['exp5', './1client_ssd/rethinkdb/rethinkdb_follower_disk_swapoff_results']
                ]
    },
]

rethinkdb_s_csv=[
    {
        'name': 'rethinkdb_saturate_leader',
        'data': [
                    ['noslow_swapoff', './saturate_tmpfs/rethinkdb/rethinkdb_noslow_memory_swapoff_results'],
                    ['exp1', './saturate_tmpfs/rethinkdb/rethinkdb_leader_memory_swapoff_results'],
                    ['exp2', './saturate_tmpfs/rethinkdb/rethinkdb_leader_memory_swapoff_results'],
                    ['exp5', './saturate_tmpfs/rethinkdb/rethinkdb_leader_memory_swapoff_results'],
                    ['exp6', './saturate_tmpfs/rethinkdb/rethinkdb_leader_memory_swapon_results'], 
                    ['noslow_swapon', './saturate_tmpfs/rethinkdb/rethinkdb_noslow_memory_swapon_results']
                ]
    },
    {
        'name': 'rethinkdb_saturate_follower',
        'data': [
                    ['noslow_swapoff', './saturate_tmpfs/rethinkdb/rethinkdb_noslow_memory_swapoff_results'],
                    ['exp5', './saturate_tmpfs/rethinkdb/rethinkdb_follower_memory_swapoff_results'],
                    ['exp6', './saturate_tmpfs/rethinkdb/rethinkdb_follower_memory_swapon_results'],
                    ['noslow_swapon', './saturate_tmpfs/rethinkdb/rethinkdb_noslow_memory_swapon_results']
                ]
    },
    {
        'name': 'rethinkdb_saturate_follower_ssd',
        'data': [
                    ['noslow_swapoff', './saturate_ssd/rethinkdb/rethinkdb_noslow_disk_swapoff_results'],
                    ['exp1', './saturate_ssd/rethinkdb/rethinkdb_follower_disk_swapoff_results'],
                    ['exp2', './saturate_ssd/rethinkdb/rethinkdb_follower_disk_swapoff_results'],
                    ['exp3', './saturate_ssd/rethinkdb/rethinkdb_follower_disk_swapoff_results'],
                    ['exp4', './saturate_ssd/rethinkdb/rethinkdb_follower_disk_swapoff_results'],
                    ['exp5', './saturate_ssd/rethinkdb/rethinkdb_follower_disk_swapoff_results']
                ]
    },
    {
        'name': 'rethinkdb_saturate_leader_ssd',
        'data': [
                    ['noslow_swapoff', './saturate_ssd/rethinkdb/rethinkdb_noslow_disk_swapoff_results'],
                    ['exp1', './saturate_ssd/rethinkdb/rethinkdb_leader_disk_swapoff_results'],
                    ['exp2', './saturate_ssd/rethinkdb/rethinkdb_leader_disk_swapoff_results'],
                    ['exp3', './saturate_ssd/rethinkdb/rethinkdb_leader_disk_swapoff_results'],
                    ['exp4', './saturate_ssd/rethinkdb/rethinkdb_leader_disk_swapoff_results'],
                    ['exp5', './saturate_ssd/rethinkdb/rethinkdb_leader_disk_swapoff_results']
                ]
    },
]

cockroachdb_csv=[
    {
        'name': 'cockroachdb_leaderhigh',
        'data': [
                    ['noslow1_swapoff', './1client_tmpfs/cockroachdb/noslow_maxthroughput'],
                    ['exp1', './1client_tmpfs/cockroachdb/maxthroughput'],
                    ['exp2', './1client_tmpfs/cockroachdb/maxthroughput'],
                    ['exp5', './1client_tmpfs/cockroachdb/maxthroughput'],
                    ['exp6', './1client_tmpfs/cockroachdb/cockroachdb_maxthroughput_memory_swapon_results'],
                    ['noslow1_swapon', './1client_tmpfs/cockroachdb/cockroachdb_noslowmaxthroughput_memory_swapon_results']
                ]
    },
    {
        'name': 'cockroachdb_leaderlow',
        'data': [
                    ['noslow1_swapoff', './1client_tmpfs/cockroachdb/cockroachdb_noslowminthroughput_memory_swapoff_results'],
                    ['exp1', './1client_tmpfs/cockroachdb/cockroachdb_minthroughput_memory_swapoff_results'],
                    ['exp2', './1client_tmpfs/cockroachdb/cockroachdb_minthroughput_memory_swapoff_results'],
                    ['exp5', './1client_tmpfs/cockroachdb/cockroachdb_minthroughput_memory_swapoff_results'],
                    ['exp6', './1client_tmpfs/cockroachdb/cockroachdb_minthroughput_memory_swapon_results'],
                    ['noslow1_swapon', './1client_tmpfs/cockroachdb/cockroachdb_noslowminthroughput_memory_swapon_results']
                ]
    },
    {
        'name': 'cockroachdb_leaderhigh_ssd',
        'data': [
                    ['noslow1_swapoff', './1client_ssd/cockroachdb/cockroachdb_noslowmaxthroughput_disk_swapoff_results'],
                    ['exp1', './1client_ssd/cockroachdb/cockroachdb_maxthroughput_disk_swapoff_results'],
                    ['exp2', './1client_ssd/cockroachdb/cockroachdb_maxthroughput_disk_swapoff_results'],
                    ['exp3', './1client_ssd/cockroachdb/cockroachdb_maxthroughput_disk_swapoff_results'],
                    ['exp4', './1client_ssd/cockroachdb/cockroachdb_maxthroughput_disk_swapoff_results'],
                    ['exp5', './1client_ssd/cockroachdb/cockroachdb_maxthroughput_disk_swapoff_results'],
                ]
    },
    {
        'name': 'cockroachdb_leaderlow_ssd',
        'data': [
                    ['noslow1_swapoff', './1client_ssd/cockroachdb/cockroachdb_noslowminthroughput_disk_swapoff_results'],
                    ['exp1', './1client_ssd/cockroachdb/cockroachdb_minthroughput_disk_swapoff_results'],
                    ['exp2', './1client_ssd/cockroachdb/cockroachdb_minthroughput_disk_swapoff_results'],
                    ['exp3', './1client_ssd/cockroachdb/cockroachdb_minthroughput_disk_swapoff_results'],
                    ['exp4', './1client_ssd/cockroachdb/cockroachdb_minthroughput_disk_swapoff_results'],
                    ['exp5', './1client_ssd/cockroachdb/cockroachdb_minthroughput_disk_swapoff_results'],
                ]
    },
]

cockroachdb_s_csv=[
    {
        'name': 'cockroachdb_saturate_leaderhigh',
        'data': [
                    ['noslow', './saturate_tmpfs/cockroachdb/cockroachdb_noslowmaxthroughput_memory_swapoff_results'],
                    ['exp1', './saturate_tmpfs/cockroachdb/cockroachdb_maxthroughput_memory_swapoff_results'],
                    ['exp2', './saturate_tmpfs/cockroachdb/cockroachdb_maxthroughput_memory_swapoff_results'],
                    ['exp5', './saturate_tmpfs/cockroachdb/cockroachdb_maxthroughput_memory_swapoff_results'],
                    ['exp6', './saturate_tmpfs/cockroachdb/cockroachdb_maxthroughput_memory_swapon_results'],
                    ['noslow1_swapon', './saturate_tmpfs/cockroachdb/cockroachdb_noslowmaxthroughput_memory_swapon_results']
                ]
    },
    {
        'name': 'cockroachdb_saturate_leaderlow',
         'data': [
                    ['noslow', './saturate_tmpfs/cockroachdb/cockroachdb_noslowminthroughput_memory_swapoff_results'],
                    ['exp1', './saturate_tmpfs/cockroachdb/cockroachdb_minthroughput_memory_swapoff_results'],
                    ['exp2', './saturate_tmpfs/cockroachdb/cockroachdb_minthroughput_memory_swapoff_results'],
                    ['exp5', './saturate_tmpfs/cockroachdb/cockroachdb_minthroughput_memory_swapoff_results'],
                    ['exp6', './saturate_tmpfs/cockroachdb/cockroachdb_minthroughput_memory_swapon_results'],
                    ['noslow1_swapon', './saturate_tmpfs/cockroachdb/cockroachdb_noslowminthroughput_memory_swapon_results']
                ]
    },
    {
        'name': 'cockroachdb_saturate_leaderhigh_ssd',
        'data': [
                    ['noslow', './saturate_ssd/cockroachdb/cockroachdb_noslowmaxthroughput_disk_swapoff_results'],
                    ['exp1', './saturate_ssd/cockroachdb/cockroachdb_maxthroughput_disk_swapoff_results'],
                    ['exp2', './saturate_ssd/cockroachdb/cockroachdb_maxthroughput_disk_swapoff_results'],
                    ['exp3', './saturate_ssd/cockroachdb/cockroachdb_maxthroughput_disk_swapoff_results'],
                    ['exp4', './saturate_ssd/cockroachdb/cockroachdb_maxthroughput_disk_swapoff_results'],
                    ['exp5', './saturate_ssd/cockroachdb/cockroachdb_maxthroughput_disk_swapoff_results']
                ]
    },
    {
        'name': 'cockroachdb_saturate_leaderlow_ssd',
        'data': [
                    ['noslow', './saturate_ssd/cockroachdb/cockroachdb_noslowminthroughput_disk_swapoff_results'],
                    ['exp1', './saturate_ssd/cockroachdb/cockroachdb_minthroughput_disk_swapoff_results'],
                    ['exp2', './saturate_ssd/cockroachdb/cockroachdb_minthroughput_disk_swapoff_results'],
                    ['exp3', './saturate_ssd/cockroachdb/cockroachdb_minthroughput_disk_swapoff_results'],
                    ['exp4', './saturate_ssd/cockroachdb/cockroachdb_minthroughput_disk_swapoff_results'],
                    ['exp5', './saturate_ssd/cockroachdb/cockroachdb_minthroughput_disk_swapoff_results']
                ]
    },
]


def getcluster(_csv, dbtype, metric, expname):    # tidb_s_csv, ops, tidb_saturate_leaderhigh_ssd
    explist=None
    for _x in _csv:
        if(_x['name']==expname):
            explist=_x['data']
    res={}
    for it in explist:
        slowres, _ =calcforexp(it[0], it[1], dbtype)
        print(slowres)
        res[it[0]]=slowres[metric]
    return(res)


def draw(metric, _list, _lim, _legend=False):
    bar_width=0.15
    _c=sns.color_palette("pastel")
    color=['black', _c[3], _c[8], _c[2], _c[9], _c[4]]
    hh=['////','----','...','xxxx','||||', '\\\\\\\\']
    exp_label=[
               ['No Slow', 'noslow'],
               ['Slow CPU', 'exp1'],
               ['CPU Contention', 'exp2'],
               ['Slow Disk', 'exp3'],
               ['Disk Contention', 'exp4'],
               ['Slow Network', 'exp5'],
              ]
    metric_label={'ops': 'Throughput', 'avg': 'Average Latency', '99': '99th Percentile Latency'}
    tick_label=[x[3] for x in _list]
    idx_tick_label=np.arange(len(tick_label))

    for _l, x in enumerate(_list):
        explist=getpercentage(x[0], x[1], x[2])
        explist['noslow']={'ops': 0, 'avg': 0, '99': 0, '999': 0, 'max': 0}
        # print(explist)
        for i, _e in enumerate(exp_label):
            dat=_e[1]
            normval=explist[dat][metric]/100+1
            barlabel=str(round(normval))
            if(round(normval)>1000):
                barlabel=str(round(normval/1000,1))+'k'
            # barlabel=str(max(round(explist[dat][metric]/100), _lim[2]))+'x'
            print(i, dat, explist[dat][metric], normval)
            if(normval>=_lim[1]):
                plt.bar(idx_tick_label[_l]+bar_width*i, _lim[2], bar_width, color=color[i], edgecolor='k')
                plt.text(idx_tick_label[_l]+bar_width*i, _lim[2]+_lim[3], barlabel, ha='center', fontsize=28, fontweight='bold')
                print(barlabel)
            else:
                plt.bar(idx_tick_label[_l]+bar_width*i, normval, bar_width, color=color[i], edgecolor='k')

        # for _d, dat in enumerate(explist):
        #     normval=(100-explist[dat][metric])/100
        #     print(_d, dat, idx_tick_label[_l]+bar_width*_d, explist[dat][metric])
        #     plt.bar(idx_tick_label[_l]+bar_width*_d, normval, bar_width, color=color[_d], hatch=hh[_d], edgecolor='black')
    
    plt.xticks(idx_tick_label+bar_width*2, tick_label)
    plt.ylabel(metric_label[metric])
    # plt.yscale('log')
    plt.ylim(_lim[0], _lim[1])
    if(_legend):
        plt.legend([x[0] for x in exp_label], loc='lower left', ncol=3, bbox_to_anchor=(0,1.05), frameon=False)
    plt.tight_layout()


drawlist_L1=[
          [mongodb_explist, 'mongodb', '/1client_ssd/mongodb/mongodb_leader_swapoff_hdd', 'MongoDB'],
          [rethinkdb_explist, 'rethinkdb', '/1client_ssd/rethinkdb/rethinkdb_leader_disk_swapoff_results', 'RethinkDB'],
          [tidb_explist, 'tidb', '/1client_ssd/tidb/tidb_leaderhigh_swapoff_hdd', 'TiDB'],
          [cockroachdb_explist, 'cockroachdb', '/1client_ssd/cockroachdb/cockroachdb_maxthroughput_disk_swapoff_results', 'CRDB'],
         ]

drawlist_F1=[
          [mongodb_explist, 'mongodb', '/1client_ssd/mongodb/mongodb_follower_swapoff_hdd', 'MongoDB'],
          [rethinkdb_explist, 'rethinkdb', '/1client_ssd/rethinkdb/rethinkdb_follower_disk_swapoff_results', 'RethinkDB'],
          [tidb_explist, 'tidb', '/1client_ssd/tidb/tidb_follower_swapoff_hdd', 'TiDB'],
          [cockroachdb_explist, 'cockroachdb', '/1client_ssd/cockroachdb/cockroachdb_minthroughput_disk_swapoff_results', 'CRDB'],
         ]

drawlist_LS=[
          [mongodb_s_explist, 'mongodb', '/saturate_ssd/mongodb/mongodb_leader_swapoff_hdd', 'MongoDB'],
          [rethinkdb_s_explist, 'rethinkdb', '/saturate_ssd/rethinkdb/rethinkdb_leader_disk_swapoff_results', 'RethinkDB'],
          [tidb_s_explist, 'tidb', '/saturate_ssd/tidb/tidb_leaderhigh_swapoff_hdd', 'TiDB'],
          [cockroachdb_s_explist, 'cockroachdb', '/saturate_ssd/cockroachdb/cockroachdb_maxthroughput_disk_swapoff_results', 'CRDB'],
         ]

drawlist_FS=[
          [mongodb_s_explist, 'mongodb', '/saturate_ssd/mongodb/mongodb_follower_swapoff_hdd', 'MongoDB'],
          [rethinkdb_s_explist, 'rethinkdb', '/saturate_ssd/rethinkdb/rethinkdb_follower_disk_swapoff_results', 'RethinkDB'],
          [tidb_s_explist, 'tidb', '/saturate_ssd/tidb/tidb_leaderlow_swapoff_hdd', 'TiDB'],
          [cockroachdb_s_explist, 'cockroachdb', '/saturate_ssd/cockroachdb/cockroachdb_minthroughput_disk_swapoff_results', 'CRDB'],
         ]



getpercentage(mongodb_explist, 'mongodb')
exportcsv(mongo_csv, 'mongodb')
getpercentage(mongodb_s_explist, 'mongodb')
exportcsv(mongo_s_csv, 'mongodb')

getpercentage(tidb_explist, 'tidb')
exportcsv(tidb_csv, 'tidb')
getpercentage(tidb_s_explist, 'tidb')
exportcsv(tidb_s_csv, 'tidb')

sizex=24
sizey=8
sizei=120

# plt.figure(figsize=(12,12), dpi=100)
plt.rc('pgf', texsystem='pdflatex')
font = {'family' : 'serif',
        'size'   : 38}
plt.rc('font', **font)

DX=1.15
DY=0.91


# plt.figure(figsize=(sizex,sizey), dpi=100)
# draw('avg',drawlist_F, [0,5.6,5], _legend=True)
# plt.show()


plt.figure(figsize=(sizex,sizey*DX), dpi=sizei)
draw('ops',drawlist_L1, [0,1.15,1, 0], _legend=True)
plt.savefig('L1ops.pdf')

plt.figure(figsize=(sizex,sizey*DY), dpi=sizei)
draw('avg',drawlist_L1, [0,46,40, 0.5])
plt.savefig('L1avg.pdf')

plt.figure(figsize=(sizex,sizey*DY), dpi=sizei)
draw('99',drawlist_L1, [0,46,40, 0.5])
plt.savefig('L199.pdf')



plt.figure(figsize=(sizex,sizey*DX), dpi=sizei)
draw('ops',drawlist_F1, [0,1.15,1, 0], _legend=True)
plt.savefig('F1ops.pdf')

plt.figure(figsize=(sizex,sizey*DY), dpi=sizei)
draw('avg',drawlist_F1, [0,3.3,3, 0.02])
plt.savefig('F1avg.pdf')

plt.figure(figsize=(sizex,sizey*DY), dpi=sizei)
draw('99',drawlist_F1, [0,3.3,3, 0.02])
plt.savefig('F199.pdf')



plt.figure(figsize=(sizex,sizey*DX), dpi=sizei)
draw('ops',drawlist_LS, [0,1.15,1,0], _legend=True)
plt.savefig('LSops.pdf')

plt.figure(figsize=(sizex,sizey*DY), dpi=sizei)
draw('avg',drawlist_LS, [0,46,40, 0.5])
plt.savefig('LSavg.pdf')

plt.figure(figsize=(sizex,sizey*DY), dpi=sizei)
draw('99',drawlist_LS, [0,46,40, 0.5])
plt.savefig('LS99.pdf')



plt.figure(figsize=(sizex,sizey*DX), dpi=sizei)
draw('ops',drawlist_FS, [0,1.15,1,0], _legend=True)
plt.savefig('FSops.pdf')

plt.figure(figsize=(sizex,sizey*DY), dpi=sizei)
draw('avg',drawlist_FS, [0,3.3,3, 0.02])
plt.savefig('FSavg.pdf')

plt.figure(figsize=(sizex,sizey*DY), dpi=sizei)
draw('99',drawlist_FS, [0,3.3,3, 0.02])
plt.savefig('FS99.pdf')


# plt.savefig('plt.pdf')
# plt.show()
