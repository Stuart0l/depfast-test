#./start_experiment.sh 3 ./workloada 600 1 azure leader swapoff mem
#./start_experiment.sh 5 ./workloada 600 2 azure leader swapoff mem
#./start_experiment.sh 5 ./workloada 600 5 azure leader swapoff mem
#./start_experiment.sh 3 ./workloada 600 6 azure leader swapon mem

#./start_experiment.sh 5 ./workloada 600 1 azure noslow swapoff mem

#./start_experiment.sh 5 ./workloada 600 1 azure follower swapoff mem
./start_experiment.sh 5 ./workloada 600 2 azure follower swapoff mem
./start_experiment.sh 5 ./workloada 600 5 azure follower swapoff mem
./start_experiment.sh 5 ./workloada 600 6 azure follower swapon mem
