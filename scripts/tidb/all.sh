#./start_experiment.sh 5 ./workloada 600 2 azure leader swapoff mem
#./start_experiment.sh 5 ./workloada 600 5 azure leader swapoff mem

#./start_experiment.sh 10 ./workloada 600 1 azure noslow1 swapoff mem
#./start_experiment.sh 10 ./workloada 600 1 azure noslow2 swapoff mem

#./start_experiment.sh 5 ./workloada 600 1 azure follower swapoff mem
#./start_experiment.sh 5 ./workloada 600 2 azure follower swapoff mem
#./start_experiment.sh 5 ./workloada 600 5 azure follower swapoff mem
#./start_experiment.sh 1 ./workloada 600 1 azure leader swapoff mem

#./start_experiment.sh 8 ./workloada 600 6 azure leaderhigh swapon mem
#./start_experiment.sh 10 ./workloada 600 6 azure follower swapon mem
./start_experiment.sh 5 ./workloada 600 6 azure noslow1 swapon mem
./start_experiment.sh 5 ./workloada 600 6 azure noslow2 swapon mem

