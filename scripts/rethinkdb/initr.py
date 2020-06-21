from rethinkdb import r
import pdb

serverIP = "10.0.0.4"

def init():
    r.connect(serverIP, 28015).repl()
    # Connection established
    try:
        r.db('ycsb').table_drop('usertable').run()
    except Exception as e:
        print("Could not delete table")
    try:
        r.db_drop('ycsb').run()
    except Exception as e:
        print("Could not delete db")

    try:
       	r.db_create('ycsb').run()
       	r.db('ycsb').table_create('usertable', replicas=3,primary_key='__pk__').run()
    except Exception as e:
       	print("Could not create table")

    # Print the primary name
    b = list(r.db('rethinkdb').table('table_status').run())
    primaryreplica = b[0]['shards'][0]['primary_replicas'][0]
    print("primaryreplica=", primaryreplica, sep='')

    replicas = b[0]['shards'][0]['replicas']
    secondaryreplica = ""
    for rep in replicas:
        if rep['server'] != primaryreplica:
            secondaryreplica = rep['server']
            break

    print("secondaryreplica=", secondaryreplica, sep='')

    res = list(r.db('rethinkdb').table('server_status').run())
    #pids = [(n['name'],n['process']['pid'],n['network']['cluster_port']) for n in res]
    namePidIpRes = [(n['name'],n['process']['pid'],n['network']['canonical_addresses'][0]['host']) for n in res]
    
    #print("primaryip=", nameToIPMap[primaryreplica], sep='')
    #print("secondaryip=", nameToIPMap[secondaryreplica], sep='')

    primarypid, secondarypid, primaryip, secondaryip = "", "", "", ""
    for p in namePidIpRes:
        if p[0] == primaryreplica:
            primarypid = p[1]
            primaryip = p[2]
        if p[0] == secondaryreplica:
            secondarypid = p[1]
            secondaryip = p[2]

    print("primarypid=", primarypid, sep='')
    print("secondarypid=", secondarypid, sep='')
    print("primaryip=", primaryip, sep='')
    print("secondaryip=", secondaryip, sep='')

def main():
    # Initialising RethinkDB
    init()

if __name__== "__main__":
    main()
