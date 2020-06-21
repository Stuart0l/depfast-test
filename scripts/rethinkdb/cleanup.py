from rethinkdb import r

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
    print("DB and table deleted")

def main():
    # Initialising RethinkDB
    print("Cleanup RethinkDB")
    init()

if __name__== "__main__":
    main()

