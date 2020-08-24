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
rethinkdb_ssd_explist=[
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

# define experiments in csv file here
rethinkdb_ssd_csv=[
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

# then get the result of each experiment
getpercentage(rethinkdb_ssd_explist, 'rethinkdb')
exportcsv(rethinkdb_ssd_csv, 'rethinkdb')

getpercentage(rethinkdb_mem_follow_explist, 'rethinkdb')
exportcsv(rethinkdb_mem_follow_csv, 'rethinkdb')

# Take args
# Depending on it trigger ssd or mem
