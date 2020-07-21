import os

def parseycsb1(fpath):
    ff=open(fpath,'r').read().split('\n')
    res={}
    for lines in ff:
        # print(lines)
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
    flist=os.listdir(fpath)
    totres={'ops': 0.0, 'avg': 0.0, '99': 0.0, '999': 0.0, 'max': 0.0}
    cnt=0
    for _fp in flist:
        if(expname in _fp):
            cnt+=1
            fp=os.path.join(fpath, _fp)
            if(dbname=='tidb'):
                res=parseycsb2(fp)
            else:
                res=parseycsb1(fp)
            print(fp, res)
            for kk in totres.keys():
                totres[kk]+=res[kk]
    for kk in totres.keys():
        totres[kk]/=cnt
    return(totres)

def compareres(expname, noslowpath, slowpath, dbname):
    noslowres=calcforexp('', noslowpath, dbname)
    slowres=calcforexp(expname, slowpath, dbname)
    res={'ops': 0.0, 'avg': 0.0, '99': 0.0, '999': 0.0, 'max': 0.0}
    res['ops']=(noslowres['ops']-slowres['ops'])/noslowres['ops']*100
    res['avg']=(slowres['avg']-noslowres['avg'])/noslowres['avg']*100
    res['99']=(slowres['99']-noslowres['99'])/noslowres['99']*100
    res['999']=(slowres['999']-noslowres['999'])/noslowres['999']*100
    res['max']=(slowres['max']-noslowres['max'])/noslowres['max']*100
    return(res)



# define experiments here, like [ exp1/exp2/exp5/exp6, folder for noslow result, folder for experiment result ]

tidb_explist=[
    # leaderhigh slowness
    ['exp1','./1client_tmpfs/tidb/tidb_noslow1_swapoff_mem_results','./1client_tmpfs/tidb/tidb_leaderhigh_swapoff_mem_results'],
    ['exp2','./1client_tmpfs/tidb/tidb_noslow1_swapoff_mem_results','./1client_tmpfs/tidb/tidb_leaderhigh_swapoff_mem_results'],
    ['exp5','./1client_tmpfs/tidb/tidb_noslow1_swapoff_mem_results','./1client_tmpfs/tidb/tidb_leaderhigh_swapoff_mem_results'],
    ['exp6','./1client_tmpfs/tidb/tidb_noslow1_swapon_mem_results','./1client_tmpfs/tidb/tidb_leaderhigh_swapon_mem_results'],
    # leaderlow slowness
    ['exp1','./1client_tmpfs/tidb/tidb_noslow1_swapoff_mem_results','./1client_tmpfs/tidb/tidb_leaderlow_swapoff_mem_results'],
    ['exp2','./1client_tmpfs/tidb/tidb_noslow1_swapoff_mem_results','./1client_tmpfs/tidb/tidb_leaderlow_swapoff_mem_results'],
    ['exp5','./1client_tmpfs/tidb/tidb_noslow1_swapoff_mem_results','./1client_tmpfs/tidb/tidb_leaderlow_swapoff_mem_results'],
    ['exp6','./1client_tmpfs/tidb/tidb_noslow1_swapon_mem_results','./1client_tmpfs/tidb/tidb_leaderlow_swapon_mem_results'],
    # follower slowness
    ['exp1','./1client_tmpfs/tidb/tidb_noslow2_swapoff_mem_results','./1client_tmpfs/tidb/tidb_follower_swapoff_mem_results'],
    ['exp2','./1client_tmpfs/tidb/tidb_noslow2_swapoff_mem_results','./1client_tmpfs/tidb/tidb_follower_swapoff_mem_results'],
    ['exp5','./1client_tmpfs/tidb/tidb_noslow2_swapoff_mem_results','./1client_tmpfs/tidb/tidb_follower_swapoff_mem_results'],
    ['exp6','./1client_tmpfs/tidb/tidb_noslow2_swapon_mem_results','./1client_tmpfs/tidb/tidb_follower_swapon_mem_results'],
]

mongodb_explist=[
    # leader slowness
    ['exp1','./1client_tmpfs/mongodb/mongodb_noslow_swapoff_mem_results','./1client_tmpfs/mongodb/mongodb_leader_swapoff_mem_results'],
    ['exp2','./1client_tmpfs/mongodb/mongodb_noslow_swapoff_mem_results','./1client_tmpfs/mongodb/mongodb_leader_swapoff_mem_results'],
    ['exp5','./1client_tmpfs/mongodb/mongodb_noslow_swapoff_mem_results','./1client_tmpfs/mongodb/mongodb_leader_swapoff_mem_results'],
    ['exp6','./1client_tmpfs/mongodb/mongodb_noslow_swapon_mem_results','./1client_tmpfs/mongodb/mongodb_leader_swapon_mem_results'],
    # follower slowness
    ['exp1','./1client_tmpfs/mongodb/mongodb_noslow_swapoff_mem_results','./1client_tmpfs/mongodb/mongodb_follower_swapoff_mem_results'],
    ['exp2','./1client_tmpfs/mongodb/mongodb_noslow_swapoff_mem_results','./1client_tmpfs/mongodb/mongodb_follower_swapoff_mem_results'],
    ['exp5','./1client_tmpfs/mongodb/mongodb_noslow_swapoff_mem_results','./1client_tmpfs/mongodb/mongodb_follower_swapoff_mem_results'],
    ['exp6','./1client_tmpfs/mongodb/mongodb_noslow_swapon_mem_results','./1client_tmpfs/mongodb/mongodb_follower_swapon_mem_results'],
]

# then get the result of each experiment

for exp in mongodb_explist:
    tt=compareres(exp[0], exp[1], exp[2], 'mongo')
    print("percentage: ", tt)
    print("")

