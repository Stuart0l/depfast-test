import os
import csv


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
                totres[kk]+=res[kk]
    for kk in totres.keys():
        totres[kk]/=cnt
    # print(listres)
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

def getpercentage(_explist, dbtype):
    for exp in _explist:
        if(exp[0]=='---'):
            print('----------------------------------------------')
        else:
            tt=compareres(exp[0], exp[1], exp[2], dbtype)
            print(exp)
            print("percentage: ", tt)
            print("")

# define experiments here, like [ exp1/exp2/exp5/exp6, folder for noslow result, folder for experiment result ]

tidb_explist=[
    # leaderhigh slowness
    ['---'],
    ['exp1','./1client_tmpfs/tidb/tidb_noslow1_swapoff_mem_results','./1client_tmpfs/tidb/tidb_leaderhigh_swapoff_mem_results'],
    ['exp2','./1client_tmpfs/tidb/tidb_noslow1_swapoff_mem_results','./1client_tmpfs/tidb/tidb_leaderhigh_swapoff_mem_results'],
    ['exp5','./1client_tmpfs/tidb/tidb_noslow1_swapoff_mem_results','./1client_tmpfs/tidb/tidb_leaderhigh_swapoff_mem_results'],
    ['exp6','./1client_tmpfs/tidb/tidb_noslow1_swapon_mem_results','./1client_tmpfs/tidb/tidb_leaderhigh_swapon_mem_results'],
    # leaderlow slowness
    ['---'],
    ['exp1','./1client_tmpfs/tidb/tidb_noslow1_swapoff_mem_results','./1client_tmpfs/tidb/tidb_leaderlow_swapoff_mem_results'],
    ['exp2','./1client_tmpfs/tidb/tidb_noslow1_swapoff_mem_results','./1client_tmpfs/tidb/tidb_leaderlow_swapoff_mem_results'],
    ['exp5','./1client_tmpfs/tidb/tidb_noslow1_swapoff_mem_results','./1client_tmpfs/tidb/tidb_leaderlow_swapoff_mem_results'],
    ['exp6','./1client_tmpfs/tidb/tidb_noslow1_swapon_mem_results','./1client_tmpfs/tidb/tidb_leaderlow_swapon_mem_results'],
    # follower slowness
    ['---'],
    ['exp1','./1client_tmpfs/tidb/tidb_noslow2_swapoff_mem_results','./1client_tmpfs/tidb/tidb_follower_swapoff_mem_results'],
    ['exp2','./1client_tmpfs/tidb/tidb_noslow2_swapoff_mem_results','./1client_tmpfs/tidb/tidb_follower_swapoff_mem_results'],
    ['exp5','./1client_tmpfs/tidb/tidb_noslow2_swapoff_mem_results','./1client_tmpfs/tidb/tidb_follower_swapoff_mem_results'],
    ['exp6','./1client_tmpfs/tidb/tidb_noslow2_swapon_mem_results','./1client_tmpfs/tidb/tidb_follower_swapon_mem_results'],
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
    # follower slowness
    ['---'],
    ['exp1','./saturate_tmpfs/tidb/tidb_noslow2_swapoff_mem_results','./saturate_tmpfs/tidb/tidb_follower_swapoff_mem_results'],
    ['exp2','./saturate_tmpfs/tidb/tidb_noslow2_swapoff_mem_results','./saturate_tmpfs/tidb/tidb_follower_swapoff_mem_results'],
    ['exp5','./saturate_tmpfs/tidb/tidb_noslow2_swapoff_mem_results','./saturate_tmpfs/tidb/tidb_follower_swapoff_mem_results'],
    ['exp6','./saturate_tmpfs/tidb/tidb_noslow2_swapon_mem_results','./saturate_tmpfs/tidb/tidb_follower_swapon_mem_results'],
]


mongodb_explist=[
    # leader slowness
    ['---'],
    ['exp1','./1client_tmpfs/mongodb/mongodb_noslow_swapoff_mem_results','./1client_tmpfs/mongodb/mongodb_leader_swapoff_mem_results'],
    ['exp2','./1client_tmpfs/mongodb/mongodb_noslow_swapoff_mem_results','./1client_tmpfs/mongodb/mongodb_leader_swapoff_mem_results'],
    ['exp5','./1client_tmpfs/mongodb/mongodb_noslow_swapoff_mem_results','./1client_tmpfs/mongodb/mongodb_leader_swapoff_mem_results'],
    ['exp6','./1client_tmpfs/mongodb/mongodb_noslow_swapon_mem_results','./1client_tmpfs/mongodb/mongodb_leader_swapon_mem_results'],
    # follower slowness
    ['---'],
    ['exp1','./1client_tmpfs/mongodb/mongodb_noslow_swapoff_mem_results','./1client_tmpfs/mongodb/mongodb_follower_swapoff_mem_results'],
    ['exp2','./1client_tmpfs/mongodb/mongodb_noslow_swapoff_mem_results','./1client_tmpfs/mongodb/mongodb_follower_swapoff_mem_results'],
    ['exp5','./1client_tmpfs/mongodb/mongodb_noslow_swapoff_mem_results','./1client_tmpfs/mongodb/mongodb_follower_swapoff_mem_results'],
    ['exp6','./1client_tmpfs/mongodb/mongodb_noslow_swapon_mem_results','./1client_tmpfs/mongodb/mongodb_follower_swapon_mem_results'],
]

mongodb_s_explist=[
    # leader slowness
    ['---'],
    ['exp1','./saturate_tmpfs/mongodb/mongodb_noslow_swapoff_mem_results','./saturate_tmpfs/mongodb/mongodb_leader_swapoff_mem_results'],
    ['exp2','./saturate_tmpfs/mongodb/mongodb_noslow_swapoff_mem_results','./saturate_tmpfs/mongodb/mongodb_leader_swapoff_mem_results'],
    ['exp5','./saturate_tmpfs/mongodb/mongodb_noslow_swapoff_mem_results','./saturate_tmpfs/mongodb/mongodb_leader_swapoff_mem_results'],
    ['exp6','./saturate_tmpfs/mongodb/mongodb_noslow_swapon_mem_results','./saturate_tmpfs/mongodb/mongodb_leader_swapon_mem_results'],
    # follower slowness
    ['---'],
    ['exp1','./saturate_tmpfs/mongodb/mongodb_noslow_swapoff_mem_results','./saturate_tmpfs/mongodb/mongodb_follower_swapoff_mem_results'],
    ['exp2','./saturate_tmpfs/mongodb/mongodb_noslow_swapoff_mem_results','./saturate_tmpfs/mongodb/mongodb_follower_swapoff_mem_results'],
    ['exp5','./saturate_tmpfs/mongodb/mongodb_noslow_swapoff_mem_results','./saturate_tmpfs/mongodb/mongodb_follower_swapoff_mem_results'],
    ['exp6','./saturate_tmpfs/mongodb/mongodb_noslow_swapon_mem_results','./saturate_tmpfs/mongodb/mongodb_follower_swapon_mem_results'],
]

rethinkdb_explist=[
    # leader slowness
    ['exp1','./1client_ssd/rethinkdb/rethinkdb_noslow_disk_swapoff_results','./1client_ssd/rethinkdb/rethinkdb_leader_disk_swapoff_results'],
    ['exp2','./1client_ssd/rethinkdb/rethinkdb_noslow_disk_swapoff_results','./1client_ssd/rethinkdb/rethinkdb_leader_disk_swapoff_results'],
    ['exp3','./1client_ssd/rethinkdb/rethinkdb_noslow_disk_swapoff_results','./1client_ssd/rethinkdb/rethinkdb_leader_disk_swapoff_results'],
    ['exp4','./1client_ssd/rethinkdb/rethinkdb_noslow_disk_swapoff_results','./1client_ssd/rethinkdb/rethinkdb_leader_disk_swapoff_results'],
    ['exp5','./1client_ssd/rethinkdb/rethinkdb_noslow_disk_swapoff_results','./1client_ssd/rethinkdb/rethinkdb_leader_disk_swapoff_results'],
    # follower slowness
    ['exp1','./1client_ssd/rethinkdb/rethinkdb_noslow_disk_swapoff_results','./1client_ssd/rethinkdb/rethinkdb_follower_disk_swapoff_results'],
    ['exp2','./1client_ssd/rethinkdb/rethinkdb_noslow_disk_swapoff_results','./1client_ssd/rethinkdb/rethinkdb_follower_disk_swapoff_results'],
    ['exp3','./1client_ssd/rethinkdb/rethinkdb_noslow_disk_swapoff_results','./1client_ssd/rethinkdb/rethinkdb_follower_disk_swapoff_results'],
    ['exp4','./1client_ssd/rethinkdb/rethinkdb_noslow_disk_swapoff_results','./1client_ssd/rethinkdb/rethinkdb_follower_disk_swapoff_results'],
    ['exp5','./1client_ssd/rethinkdb/rethinkdb_noslow_disk_swapoff_results','./1client_ssd/rethinkdb/rethinkdb_follower_disk_swapoff_results'],
]


rethinkdb_mem_explist=[
    # leader slowness
    ['exp1','./1client_tmpfs/rethinkdb/noslow_swapoff','./1client_tmpfs/rethinkdb/leader'],
    ['exp2','./1client_tmpfs/rethinkdb/noslow_swapoff','./1client_tmpfs/rethinkdb/leader'],
    ['exp5','./1client_tmpfs/rethinkdb/noslow_swapoff','./1client_tmpfs/rethinkdb/leader'],
    ['exp6','./1client_tmpfs/rethinkdb/rethinkdb_noslow_memory_swapon_results','./1client_tmpfs/rethinkdb/rethinkdb_leader_memory_swapon_results'],
    # follower slowness
    #['exp5','./1client_tmpfs/rethinkdb/rethinkdb_noslow_memory_swapoff_results','./1client_tmpfs/rethinkdb/rethinkdb_follower_memory_swapoff_results'],
    #['exp6','./1client_tmpfs/rethinkdb/rethinkdb_noslow_memory_swapon_results','./1client_tmpfs/rethinkdb/rethinkdb_follower_memory_swapon_results'],
]


rethinkdb_mem_follow_explist=[
    # follower slowness
    ['exp5','./1client_tmpfs/rethinkdb/rethinkdb_noslow_memory_swapoff_results','./1client_tmpfs/rethinkdb/rethinkdb_follower_memory_swapoff_results'],
    ['exp6','./1client_tmpfs/rethinkdb/rethinkdb_noslow_memory_swapon_results','./1client_tmpfs/rethinkdb/rethinkdb_follower_memory_swapon_results'],
]

cockroachdb_explist=[
    # maxthroughput slowness
    ['exp6','./1client_tmpfs/cockroachdb/cockroachdb_noslowmaxthroughput_memory_swapon_results','./1client_tmpfs/cockroachdb/cockroachdb_maxthroughput_memory_swapon_results'],
    # minthroughput slowness
    ['exp1','./1client_tmpfs/cockroachdb/cockroachdb_noslowminthroughput_memory_swapoff_results','./1client_tmpfs/cockroachdb/cockroachdb_minthroughput_memory_swapoff_results'],
    ['exp2','./1client_tmpfs/cockroachdb/cockroachdb_noslowminthroughput_memory_swapoff_results','./1client_tmpfs/cockroachdb/cockroachdb_minthroughput_memory_swapoff_results'],
    ['exp5','./1client_tmpfs/cockroachdb/cockroachdb_noslowminthroughput_memory_swapoff_results','./1client_tmpfs/cockroachdb/cockroachdb_minthroughput_memory_swapoff_results'],
    ['exp6','./1client_tmpfs/cockroachdb/cockroachdb_noslowminthroughput_memory_swapon_results','./1client_tmpfs/cockroachdb/cockroachdb_minthroughput_memory_swapon_results'],
]

cockroachdb_ssd_explist=[
    # follower slowness
    ['exp1','./1client_ssd/cockroachdb/cockroachdb_noslowfollower_disk_swapoff_results','./1client_ssd/cockroachdb/cockroachdb_follower_disk_swapoff_results'],
    ['exp2','./1client_ssd/cockroachdb/cockroachdb_noslowfollower_disk_swapoff_results','./1client_ssd/cockroachdb/cockroachdb_follower_disk_swapoff_results'],
    ['exp3','./1client_ssd/cockroachdb/cockroachdb_noslowfollower_disk_swapoff_results','./1client_ssd/cockroachdb/cockroachdb_follower_disk_swapoff_results'],
    ['exp4','./1client_ssd/cockroachdb/cockroachdb_noslowfollower_disk_swapoff_results','./1client_ssd/cockroachdb/cockroachdb_follower_disk_swapoff_results'],
    #['exp5','./1client_ssd/cockroachdb/cockroachdb_noslowfollower_disk_swapoff_results','./1client_ssd/cockroachdb/cockroachdb_follower_disk_swapoff_results'],

    # maxthroughput slowness
    ['exp1','./1client_ssd/cockroachdb/cockroachdb_noslowmaxthroughput_disk_swapoff_results','./1client_ssd/cockroachdb/cockroachdb_maxthroughput_disk_swapoff_results'],
    ['exp2','./1client_ssd/cockroachdb/cockroachdb_noslowmaxthroughput_disk_swapoff_results','./1client_ssd/cockroachdb/cockroachdb_maxthroughput_disk_swapoff_results'],
    ['exp3','./1client_ssd/cockroachdb/cockroachdb_noslowmaxthroughput_disk_swapoff_results','./1client_ssd/cockroachdb/cockroachdb_maxthroughput_disk_swapoff_results'],
    ['exp4','./1client_ssd/cockroachdb/cockroachdb_noslowmaxthroughput_disk_swapoff_results','./1client_ssd/cockroachdb/cockroachdb_maxthroughput_disk_swapoff_results'],
    ['exp5','./1client_ssd/cockroachdb/cockroachdb_noslowmaxthroughput_disk_swapoff_results','./1client_ssd/cockroachdb/cockroachdb_maxthroughput_disk_swapoff_results'],

    # minthroughput slowness
    ['exp1','./1client_ssd/cockroachdb/cockroachdb_noslowminthroughput_disk_swapoff_results','./1client_ssd/cockroachdb/cockroachdb_minthroughput_disk_swapoff_results'],
    ['exp2','./1client_ssd/cockroachdb/cockroachdb_noslowminthroughput_disk_swapoff_results','./1client_ssd/cockroachdb/cockroachdb_minthroughput_disk_swapoff_results'],
    ['exp3','./1client_ssd/cockroachdb/cockroachdb_noslowminthroughput_disk_swapoff_results','./1client_ssd/cockroachdb/cockroachdb_minthroughput_disk_swapoff_results'],
    ['exp4','./1client_ssd/cockroachdb/cockroachdb_noslowminthroughput_disk_swapoff_results','./1client_ssd/cockroachdb/cockroachdb_minthroughput_disk_swapoff_results'],
    ['exp5','./1client_ssd/cockroachdb/cockroachdb_noslowminthroughput_disk_swapoff_results','./1client_ssd/cockroachdb/cockroachdb_minthroughput_disk_swapoff_results'],
]
# define experiments in csv file here

tidb_csv=[
    {
        'name': 'tidb_leaderhigh',
        'data': [
                    ['noslow1_swapoff', './1client_tmpfs/tidb/tidb_noslow1_swapoff_mem_results'],
                    ['exp1', './1client_tmpfs/tidb/tidb_leaderhigh_swapoff_mem_results'],
                    ['exp2', './1client_tmpfs/tidb/tidb_leaderhigh_swapoff_mem_results'],
                    ['exp5', './1client_tmpfs/tidb/tidb_leaderhigh_swapoff_mem_results'],
                    ['exp6', './1client_tmpfs/tidb/tidb_leaderhigh_swapon_mem_results'],
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
        'name': 'tidb_follower',
        'data': [
                    ['noslow2_swapoff', './1client_tmpfs/tidb/tidb_noslow2_swapoff_mem_results'],
                    ['exp1', './1client_tmpfs/tidb/tidb_follower_swapoff_mem_results'],
                    ['exp2', './1client_tmpfs/tidb/tidb_follower_swapoff_mem_results'],
                    ['exp5', './1client_tmpfs/tidb/tidb_follower_swapoff_mem_results'],
                    ['exp6', './1client_tmpfs/tidb/tidb_follower_swapon_mem_results'],
                    ['noslow2_swapon', './1client_tmpfs/tidb/tidb_noslow2_swapon_mem_results']
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
        'name': 'tidb_saturate_follower',
        'data': [
                    ['noslow2_swapoff', './saturate_tmpfs/tidb/tidb_noslow2_swapoff_mem_results'],
                    ['exp1', './saturate_tmpfs/tidb/tidb_follower_swapoff_mem_results'],
                    ['exp2', './saturate_tmpfs/tidb/tidb_follower_swapoff_mem_results'],
                    ['exp5', './saturate_tmpfs/tidb/tidb_follower_swapoff_mem_results'],
                    ['exp6', './saturate_tmpfs/tidb/tidb_follower_swapon_mem_results'],
                    ['noslow2_swapon', './saturate_tmpfs/tidb/tidb_noslow2_swapon_mem_results']
                ]
    },
]

mongo_csv=[
    {
        'name': 'mongodb_follower',
        'data': [
                    ['noslow_swapoff', './1client_tmpfs/mongodb/mongodb_noslow_swapoff_mem_results'],
                    ['exp1', './1client_tmpfs/mongodb/mongodb_follower_swapoff_mem_results'],
                    ['exp2', './1client_tmpfs/mongodb/mongodb_follower_swapoff_mem_results'],
                    ['exp5', './1client_tmpfs/mongodb/mongodb_follower_swapoff_mem_results'],
                    ['exp6', './1client_tmpfs/mongodb/mongodb_follower_swapon_mem_results'],
                    ['noslow_swapon', './1client_tmpfs/mongodb/mongodb_noslow_swapon_mem_results']
                ]
    },
    {
        'name': 'mongodb_leader',
        'data': [
                    ['noslow_swapoff', './1client_tmpfs/mongodb/mongodb_noslow_swapoff_mem_results'],
                    ['exp1', './1client_tmpfs/mongodb/mongodb_leader_swapoff_mem_results'],
                    ['exp2', './1client_tmpfs/mongodb/mongodb_leader_swapoff_mem_results'],
                    ['exp5', './1client_tmpfs/mongodb/mongodb_leader_swapoff_mem_results'],
                    ['exp6', './1client_tmpfs/mongodb/mongodb_leader_swapon_mem_results'],
                    ['noslow_swapon', './1client_tmpfs/mongodb/mongodb_noslow_swapon_mem_results']
                ]
    },
]

mongo_s_csv=[
    {
        'name': 'mongodb_saturate_follower',
        'data': [
                    ['noslow_swapoff', './saturate_tmpfs/mongodb/mongodb_noslow_swapoff_mem_results'],
                    ['exp1', './saturate_tmpfs/mongodb/mongodb_follower_swapoff_mem_results'],
                    ['exp2', './saturate_tmpfs/mongodb/mongodb_follower_swapoff_mem_results'],
                    ['exp5', './saturate_tmpfs/mongodb/mongodb_follower_swapoff_mem_results'],
                    ['exp6', './saturate_tmpfs/mongodb/mongodb_follower_swapon_mem_results'],
                    ['noslow_swapon', './saturate_tmpfs/mongodb/mongodb_noslow_swapon_mem_results']
                ]
    },
    {
        'name': 'mongodb_saturate_leader',
        'data': [
                    ['noslow_swapoff', './saturate_tmpfs/mongodb/mongodb_noslow_swapoff_mem_results'],
                    ['exp1', './saturate_tmpfs/mongodb/mongodb_leader_swapoff_mem_results'],
                    ['exp2', './saturate_tmpfs/mongodb/mongodb_leader_swapoff_mem_results'],
                    ['exp5', './saturate_tmpfs/mongodb/mongodb_leader_swapoff_mem_results'],
                    ['exp6', './saturate_tmpfs/mongodb/mongodb_leader_swapon_mem_results'],
                    ['noslow_swapon', './saturate_tmpfs/mongodb/mongodb_noslow_swapon_mem_results']
                ]
    },
]

rethinkdb_csv=[
    {
        'name': 'rethinkdb_follower',
        'data': [
                    ['noslow_swapoff', './1client_ssd/rethinkdb/rethinkdb_noslow_disk_swapoff_results'],
                    ['exp1', './1client_ssd/rethinkdb/rethinkdb_follower_disk_swapoff_results'],
                    ['exp2', './1client_ssd/rethinkdb/rethinkdb_follower_disk_swapoff_results'],
                    ['exp3', './1client_ssd/rethinkdb/rethinkdb_follower_disk_swapoff_results'],
                    ['exp4', './1client_ssd/rethinkdb/rethinkdb_follower_disk_swapoff_results'],
                    ['exp5', './1client_ssd/rethinkdb/rethinkdb_follower_disk_swapoff_results']
                ]
    },
    {
        'name': 'rethinkdb_leader',
        'data': [
                    ['noslow_swapoff', './1client_ssd/rethinkdb/rethinkdb_noslow_disk_swapoff_results'],
                    ['exp1', './1client_ssd/rethinkdb/rethinkdb_leader_disk_swapoff_results'],
                    ['exp2', './1client_ssd/rethinkdb/rethinkdb_leader_disk_swapoff_results'],
                    ['exp3', './1client_ssd/rethinkdb/rethinkdb_leader_disk_swapoff_results'],
                    ['exp4', './1client_ssd/rethinkdb/rethinkdb_leader_disk_swapoff_results'],
                    ['exp5', './1client_ssd/rethinkdb/rethinkdb_leader_disk_swapoff_results']
                ]
    },
]

"""
{
    'name': 'rethinkdb_follower',
    'data': [
                ['noslow_swapoff', './1client_tmpfs/rethinkdb/rethinkdb_noslow_memory_swapoff_results'],
                ['exp5', './1client_tmpfs/rethinkdb/rethinkdb_follower_memory_swapoff_results'],
                ['exp6', './1client_tmpfs/rethinkdb/rethinkdb_follower_memory_swapon_results'],
                ['noswlow_swapon', './1client_tmpfs/rethinkdb/rethinkdb_noslow_memory_swapon_results']
            ]
},
"""
rethinkdb_mem_csv=[
    {
        'name': 'rethinkdb_leader',
        'data': [
                    ['noslow_swapoff', './1client_tmpfs/rethinkdb/noslow_swapoff'],
                    ['exp1', './1client_tmpfs/rethinkdb/leader'],
                    ['exp2', './1client_tmpfs/rethinkdb/leader'],
                    ['exp5', './1client_tmpfs/rethinkdb/leader'],
                    ['exp6', './1client_tmpfs/rethinkdb/rethinkdb_leader_memory_swapon_results'],
                    ['noslow_swapon', './1client_tmpfs/rethinkdb/rethinkdb_noslow_memory_swapon_results']
                ]
    },
]

rethinkdb_mem_follow_csv=[
    {
    'name': 'rethinkdb_follower',
    'data': [
                ['noslow_swapoff', './1client_tmpfs/rethinkdb/rethinkdb_noslow_memory_swapoff_results'],
                ['exp5', './1client_tmpfs/rethinkdb/rethinkdb_follower_memory_swapoff_results'],
                ['exp6', './1client_tmpfs/rethinkdb/rethinkdb_follower_memory_swapon_results'],
                ['noslow_swapon', './1client_tmpfs/rethinkdb/rethinkdb_noslow_memory_swapon_results']
            ]
    },
]

rethinkdb_mem_follow_exp6_csv=[
    {
    'name': 'rethinkdb_follower',
    'data': [
                ['exp6', './1client_tmpfs/rethinkdb/rethinkdb_follower_memory_swapon_results'],
                ['noslow_swapon', './1client_tmpfs/rethinkdb/rethinkdb_noslow_memory_swapon_results']
            ]
    },
]

rethinkdb_mem_follow_exp6=[
    # follower slowness
    ['exp6','./1client_tmpfs/rethinkdb/rethinkdb_noslow_memory_swapon_results','./1client_tmpfs/rethinkdb/rethinkdb_follower_memory_swapon_results'],
]


cockroachdb_csv = [
    {
        'name': 'cockroachdb_maxthroughput',
        'data': [
                    ['noslow1_swapon', './1client_tmpfs/cockroachdb/cockroachdb_noslowmaxthroughput_memory_swapon_results'],
                    ['exp6', './1client_tmpfs/cockroachdb/cockroachdb_maxthroughput_memory_swapon_results']
                ]
    },
    {
        'name': 'cockroachdb_minthroughput',
        'data': [
                    ['noslow1_swapoff', './1client_tmpfs/cockroachdb/cockroachdb_noslowminthroughput_memory_swapoff_results'],
                    ['exp1', './1client_tmpfs/cockroachdb/cockroachdb_minthroughput_memory_swapoff_results'],
                    ['exp2', './1client_tmpfs/cockroachdb/cockroachdb_minthroughput_memory_swapoff_results'],
                    ['exp5', './1client_tmpfs/cockroachdb/cockroachdb_minthroughput_memory_swapoff_results'],
                    ['exp6', './1client_tmpfs/cockroachdb/cockroachdb_minthroughput_memory_swapon_results'],
                    ['noslow1_swapon', './1client_tmpfs/cockroachdb/cockroachdb_noslowminthroughput_memory_swapon_results']
                ]
    },
]

cockroachdb_ssd_csv = [
    {
        'name': 'cockroachdb_minthroughput',
        'data': [
                    ['noslow', './1client_ssd/cockroachdb/cockroachdb_noslowminthroughput_disk_swapoff_results'],
                    ['exp1', './1client_ssd/cockroachdb/cockroachdb_minthroughput_disk_swapoff_results'],
                    ['exp2', './1client_ssd/cockroachdb/cockroachdb_minthroughput_disk_swapoff_results'],
                    ['exp3', './1client_ssd/cockroachdb/cockroachdb_minthroughput_disk_swapoff_results'],
                    ['exp4', './1client_ssd/cockroachdb/cockroachdb_minthroughput_disk_swapoff_results'],
                    ['exp5', './1client_ssd/cockroachdb/cockroachdb_minthroughput_disk_swapoff_results']
                ]
    },
    {
        'name': 'cockroachdb_maxthroughput',
        'data': [
                    ['noslow', './1client_ssd/cockroachdb/cockroachdb_noslowmaxthroughput_disk_swapoff_results'],
                    ['exp1', './1client_ssd/cockroachdb/cockroachdb_maxthroughput_disk_swapoff_results'],
                    ['exp2', './1client_ssd/cockroachdb/cockroachdb_maxthroughput_disk_swapoff_results'],
                    ['exp3', './1client_ssd/cockroachdb/cockroachdb_maxthroughput_disk_swapoff_results'],
                    ['exp4', './1client_ssd/cockroachdb/cockroachdb_maxthroughput_disk_swapoff_results'],
                    ['exp5', './1client_ssd/cockroachdb/cockroachdb_maxthroughput_disk_swapoff_results']
                ]
    },
    {
        'name': 'cockroachdb_follower',
        'data': [
                    ['noslow', './1client_ssd/cockroachdb/cockroachdb_noslowfollower_disk_swapoff_results'],
                    ['exp1', './1client_ssd/cockroachdb/cockroachdb_follower_disk_swapoff_results'],
                    ['exp2', './1client_ssd/cockroachdb/cockroachdb_follower_disk_swapoff_results'],
                    ['exp3', './1client_ssd/cockroachdb/cockroachdb_follower_disk_swapoff_results'],
                    ['exp4', './1client_ssd/cockroachdb/cockroachdb_follower_disk_swapoff_results']
                ]
    },
]

# then get the result of each experiment

getpercentage(mongodb_explist, 'mongodb')
exportcsv(mongo_csv, 'mongodb')
getpercentage(mongodb_s_explist, 'mongodb')
exportcsv(mongo_s_csv, 'mongodb')
# getpercentage(mongodb_explist, 'mongodb')
# exportcsv(mongo_csv, 'mongodb')
# getpercentage(mongodb_s_explist, 'mongodb')
# exportcsv(mongo_s_csv, 'mongodb')

# getpercentage(tidb_explist, 'tidb')
# exportcsv(tidb_csv, 'tidb')
# getpercentage(tidb_s_explist, 'tidb')
# exportcsv(tidb_s_csv, 'tidb')

#getpercentage(rethinkdb_explist, 'rethinkdb')
#exportcsv(rethinkdb_csv, 'rethinkdb')

# getpercentage(rethinkdb_explist, 'cockroachdb')
# exportcsv(rethinkdb_csv, 'cockroachdb')

#getpercentage(cockroachdb_ssd_explist, 'cockroachdb')
#exportcsv(cockroachdb_ssd_csv, 'cockroachdb')

# getpercentage(rethinkdb_mem_follow_explist, 'rethinkdb')
# exportcsv(rethinkdb_mem_follow_csv, 'rethinkdb')

getpercentage(rethinkdb_mem_follow_exp6, 'rethinkdb')
exportcsv(rethinkdb_mem_follow_exp6_csv, 'rethinkdb')
