import json

serverMapping = {
        "mongodbaaa-1:27017": "10.0.0.11",
        "mongodbaaa-2:27017": "10.0.0.12",
        "mongodbaaa-3:27017": "10.0.0.13",
    }

def main():
    with open('result.json', 'r') as f:
        my_dict = json.load(f)

    primary, secondary = "", ""
    for d in my_dict:
        if d['stateStr'] == "PRIMARY":
            primary = serverMapping[d["name"]]
        if d['stateStr'] == "SECONDARY":
            secondary = serverMapping[d["name"]]

    print "primary", primary
    print "secondary", secondary

if __name__== "__main__":
    main()
