from rethinkdb import r
import sys

def init(serverIP):
    print("connecting to server ", serverIP)
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
    print("DB and table deleted")

def main(serverip):
    # Initialising RethinkDB
    print("Cleanup RethinkDB")
    init(serverip)

if __name__== "__main__":
    if len(sys.argv) != 2:
        print("Invalid number of args. Need to pass a rethinkdb server ip.")
        sys.exit(1)
    main(sys.argv[1])
