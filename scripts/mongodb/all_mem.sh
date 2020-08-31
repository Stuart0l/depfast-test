#./start_experiment.sh 1 workloada 300 1 azure leader swapoff mem 1
#./start_experiment.sh 1 workloada 300 2 azure leader swapoff mem 1
#./start_experiment.sh 1 workloada 300 5 azure leader swapoff mem 1
#./start_experiment.sh 1 workloada 300 6 azure leader swapon mem 1

./start_experiment.sh 1 workloada 300 1 azure noslow swapoff mem 1
./start_experiment.sh 1 workloada 300 1 azure noslow swapon mem 1

./start_experiment.sh 1 workloada 300 1 azure follower swapoff mem 1
./start_experiment.sh 1 workloada 300 2 azure follower swapoff mem 1
./start_experiment.sh 1 workloada 300 5 azure follower swapoff mem 1
./start_experiment.sh 1 workloada 300 6 azure follower swapon mem 1
