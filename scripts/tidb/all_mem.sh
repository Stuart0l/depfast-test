#./start_experiment.sh 1 ./workloada 600 1 azure leaderlow swapoff mem 1
#./start_experiment.sh 1 ./workloada 600 2 azure leaderlow swapoff mem 1
#./start_experiment.sh 1 ./workloada 500 5 azure leaderlow swapoff mem 1
./start_experiment.sh 1 ./workloada 300 6 azure leaderlow swapon mem 1

#./start_experiment.sh 1 ./workloada 600 1 azure leaderhigh swapoff mem 1
#./start_experiment.sh 1 ./workloada 600 2 azure leaderhigh swapoff mem 1
#./start_experiment.sh 1 ./workloada 600 5 azure leaderhigh swapoff mem 1
#./start_experiment.sh 1 ./workloada 600 6 azure leaderhigh swapon mem 1

./start_experiment.sh 1 ./workloada 300 1 azure noslow1 swapoff mem 1
#./start_experiment.sh 1 ./workloada 300 1 azure noslow2 swapoff mem 1

#./start_experiment.sh 1 ./workloada 600 1 azure follower swapoff mem 1
#./start_experiment.sh 1 ./workloada 600 2 azure follower swapoff mem 1
#./start_experiment.sh 1 ./workloada 600 5 azure follower swapoff mem 1
#./start_experiment.sh 1 ./workloada 600 6 azure follower swapon mem 1

./start_experiment.sh 1 ./workloada 300 6 azure noslow1 swapon mem 1
#./start_experiment.sh 1 ./workloada 600 6 azure noslow2 swapon mem 1

