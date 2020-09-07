#./start_experiment.sh 1 workloads 300 1 azure leader swapoff mem 32
#./start_experiment.sh 1 workloads 300 2 azure leader swapoff mem 32
#./start_experiment.sh 1 workloads 300 5 azure leader swapoff mem 32
#./start_experiment.sh 1 workloads 300 6 azure leader swapon mem 32

./start_experiment.sh 1 workloads 300 1 azure noslow swapoff mem 32
./start_experiment.sh 1 workloads 300 1 azure noslow swapon mem 32

#./start_experiment.sh 1 workloads 300 1 azure follower swapoff mem 32
#./start_experiment.sh 1 workloads 300 2 azure follower swapoff mem 32
#./start_experiment.sh 1 workloads 300 5 azure follower swapoff mem 32
#./start_experiment.sh 1 workloads 300 6 azure follower swapon mem 32



