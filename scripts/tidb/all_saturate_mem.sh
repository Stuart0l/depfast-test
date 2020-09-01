#./start_experiment.sh 5 ./workloads 600 1 azure leaderlow swapoff mem 16
./start_experiment.sh 5 ./workloads 600 2 azure leaderlow swapoff mem 16
#./start_experiment.sh 5 ./workloads 600 5 azure leaderlow swapoff mem 16
#./start_experiment.sh 5 ./workloads 600 6 azure leaderlow swapon mem 16

#./start_experiment.sh 5 ./workloads 600 1 azure leaderhigh swapoff mem 16
#./start_experiment.sh 5 ./workloads 600 2 azure leaderhigh swapoff mem 16
#./start_experiment.sh 5 ./workloads 600 5 azure leaderhigh swapoff mem 16
#./start_experiment.sh 5 ./workloads 600 6 azure leaderhigh swapon mem 16

#./start_experiment.sh 5 ./workloads 600 1 azure noslow1 swapoff mem 16
./start_experiment.sh 5 ./workloads 600 1 azure noslow2 swapoff mem 16

#./start_experiment.sh 5 ./workloads 600 1 azure follower swapoff mem 16
#./start_experiment.sh 5 ./workloads 600 2 azure follower swapoff mem 16
#./start_experiment.sh 5 ./workloads 600 5 azure follower swapoff mem 16
#./start_experiment.sh 5 ./workloads 600 6 azure follower swapon mem 16

./start_experiment.sh 5 ./workloads 600 6 azure noslow1 swapon mem 16
./start_experiment.sh 5 ./workloads 600 6 azure noslow2 swapon mem 16


#az vm deallocate --resource-group DepFast --name tidb_pd

