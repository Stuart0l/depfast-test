# MongoDB

Instructions to run the script -
1. Create GCP VMs for 1 client and 3 servers.
2. Setup server configs as mentioned in - https://docs.google.com/document/d/1Kxa6Cf5CHWR_5_Kk6LGMoj844nSY-E_zaXMkuWEqqAI/edit.
3. Specify the ipaddress and name of the server machines in the given script and helper files - *.sh, parse.py and init_script.js files.
4. Run the start_follower_exp.sh script for follower experiments, start_leader_exp.sh for leader experiments or start_noslow.sh for no slowness case on the client VM.

The arguments to the script should be given as follows - <br>
No slow - <br>
```
./start_noslow.sh 5 workloads/workloada_more 900
```
1st arg - number of trials  <br>
2nd arg - workload  <br>
3rd arg - number of seconds to run  <br>

Follower slowness -  <br>
```
./start_follower_exp.sh 5 workloads/workloada_more 900 5
```
1st arg - number of trials  <br>
2nd arg - workload  <br>
3rd arg - number of seconds to run  <br>
4th arg - experiment number(1/2/3/4/5)  <br>
Results stored under results/ directory.

Leader slowness -  <br>
```
./start_leader_exp.sh 5 workloads/workloada_more 900 5
```
1st arg - number of trials  <br>
2nd arg - workload  <br>
3rd arg - number of seconds to run  <br>
4th arg - experiment number(1/2/3/4/5)  <br>
Results stored under leader_results/ directory.

The complete list of experiments can be found here - https://docs.google.com/document/d/1uvgUHcrJQrkyBdbZu1LQNAsYhnThb1Cj8qJVA06WA2A/edit?ts=5e3b6a40#

Known limitations/TODO - <br>
1. Currently optimised for GCP. Need couple of modifications for AWS.
2. Need to change the name and IP address of the servers in helper files - init_script.js and parse.py respectively, also in the script files.  
3. Spwans a single client rather than multiple clients.
