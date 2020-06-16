# RethinkDB

Instructions to run the script -
1. Create VMs for 1 client and 3 servers.
2. Setup server configs as mentioned in - https://docs.google.com/document/d/1Kxa6Cf5CHWR_5_Kk6LGMoj844nSY-E_zaXMkuWEqqAI/edit.
3. Specify the ipaddress and name of the server machines in the given script and helper files - start_experiment.sh, cleanup.py and initr.py
4. Run the start_experiment.sh with appropriate arguments on the client VM.

The arguments to the script should be given as follows - <br>
No slowness - 
```
./start_experiment.sh 100 workloads/workloada_more 900 5 gcp noslow
```
1st arg - number of trials  <br>
2nd arg - workload  <br>
3rd arg - number of seconds to run  <br>
4th arg - experiment to run(1,2,3,4,5)  <br>
5th arg - host type(gcp/aws)  <br>
6th arg - type of experiment(follower/leader/noslow)  <br>

Follower slowness -  <br>
```
./start_experiment.sh 100 workloads/workloada_more 900 5 gcp follower
```
Leader slowness -  <br>
```
./start_experiment.sh 100 workloads/workloada_more 900 5 gcp leader
```

The complete list of experiments can be found here - https://docs.google.com/document/d/1uvgUHcrJQrkyBdbZu1LQNAsYhnThb1Cj8qJVA06WA2A/edit?ts=5e3b6a40#

Known limitations/TODO - <br>
1. Spawns a single client rather than multiple clients.
2. Only GCP host type supported. 
