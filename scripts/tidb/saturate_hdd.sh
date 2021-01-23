#./start_experiment_hdd.sh 5 ./workloadsd 300 1 azure noslow1 swapoff hdd 512

#./start_experiment_hdd.sh 5 ./workloadsd 300 1 azure leaderhigh swapoff hdd 512
#./start_experiment_hdd.sh 5 ./workloadsd 300 2 azure leaderhigh swapoff hdd 512
#./start_experiment_hdd.sh 5 ./workloadsd 300 3 azure leaderhigh swapoff hdd 512
#./start_experiment_hdd.sh 5 ./workloadsd 300 4 azure leaderhigh swapoff hdd 512
#./start_experiment_hdd.sh 5 ./workloadsd 300 5 azure leaderhigh swapoff hdd 512

#./start_experiment_hdd.sh 5 ./workloadsd 300 1 azure leaderlow swapoff hdd 512
#./start_experiment_hdd.sh 5 ./workloadsd 300 2 azure leaderlow swapoff hdd 512
#./start_experiment_hdd.sh 5 ./workloadsd 300 3 azure leaderlow swapoff hdd 512
#./start_experiment_hdd.sh 5 ./workloadsd 300 4 azure leaderlow swapoff hdd 512
#./start_experiment_hdd.sh 5 ./workloadsd 300 5 azure leaderlow swapoff hdd 512

#./start_experiment_hdd.sh 1 ./workloadsd 300 1 azure noslow2 swapoff hdd 512


#./start_experiment_hdd.sh 1 ./workloadsd 300 1 azure follower swapoff hdd 512
#./start_experiment_hdd.sh 1 ./workloadsd 300 2 azure follower swapoff hdd 512
#./start_experiment_hdd.sh 1 ./workloadsd 300 3 azure follower swapoff hdd 512
#./start_experiment_hdd.sh 1 ./workloadsd 300 4 azure follower swapoff hdd 512
#./start_experiment_hdd.sh 1 ./workloadsd 300 5 azure follower swapoff hdd 512


#./start_experiment_hdd.sh 5 ./workloadsd 300 6 azure leaderhigh swapon hdd 512
#./start_experiment_hdd.sh 5 ./workloadsd 300 6 azure leaderlow swapon hdd 512
#./start_experiment_hdd.sh 5 ./workloadsd 300 6 azure follower swapon hdd 512
#./start_experiment_hdd.sh 5 ./workloadsd 300 1 azure noslow1 swapon hdd 512
#./start_experiment_hdd.sh 5 ./workloadsd 300 1 azure noslow2 swapon hdd 512




sed -i 's#raftstore.store-pool-size: 1#raftstore.store-pool-size: 4#g' tidb_restrict_hdd.yaml 
./start_experiment_hdd.sh 1 ./workloadsd 300 1 azure noslow2 swapoff hdd 512
mv tidblogs tidblogs_no4
mv tidb_follower_swapoff_hdd_512_results/exp5_trial_1.txt ./tidbycsb_no4
./start_experiment_hdd.sh 1 ./workloadsd 300 5 azure follower swapoff hdd 512
mv tidblogs tidblogs_slow4
mv tidb_follower_swapoff_hdd_512_results/exp5_trial_1.txt ./tidbycsb_slow4


sed -i 's#raftstore.store-pool-size: 4#raftstore.store-pool-size: 1#g' tidb_restrict_hdd.yaml
./start_experiment_hdd.sh 1 ./workloadsd 300 1 azure noslow2 swapoff hdd 512
mv tidblogs tidblogs_no1
mv tidb_follower_swapoff_hdd_512_results/exp5_trial_1.txt ./tidbycsb_no1
./start_experiment_hdd.sh 1 ./workloadsd 300 5 azure follower swapoff hdd 512
mv tidblogs tidblogs_slow1
mv tidb_follower_swapoff_hdd_512_results/exp5_trial_1.txt ./tidbycsb_slow1




