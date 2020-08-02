#./start_experiment.sh 5 ./workloads 600 1 azure leaderlow swapoff mem
#./start_experiment.sh 5 ./workloads 600 2 azure leaderlow swapoff mem
#./start_experiment.sh 5 ./workloads 600 5 azure leaderlow swapoff mem
#./start_experiment.sh 5 ./workloads 600 6 azure leaderlow swapon mem

#./start_experiment.sh 5 ./workloads 600 1 azure leaderhigh swapoff mem
#./start_experiment.sh 5 ./workloads 600 2 azure leaderhigh swapoff mem
#./start_experiment.sh 5 ./workloads 600 5 azure leaderhigh swapoff mem
#./start_experiment.sh 5 ./workloads 600 6 azure leaderhigh swapon mem

#./start_experiment.sh 5 ./workloads 300 1 azure noslow1 swapoff mem
#./start_experiment.sh 5 ./workloads 300 1 azure noslow2 swapoff mem

#./start_experiment.sh 5 ./workloads 300 1 azure follower swapoff mem
#./start_experiment.sh 5 ./workloads 300 2 azure follower swapoff mem
#./start_experiment.sh 5 ./workloads 300 5 azure follower swapoff mem
#./start_experiment.sh 5 ./workloads 300 6 azure follower swapon mem

./start_experiment.sh 5 ./workloads 300 6 azure noslow1 swapon mem
./start_experiment.sh 5 ./workloads 300 6 azure noslow2 swapon mem


az vm deallocate --resource-group DepFast --name tidb_pd

