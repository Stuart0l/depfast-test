./start_experiment.sh 5 workloada 300 1 azure leader swapoff mem
./start_experiment.sh 5 workloada 300 2 azure leader swapoff mem
./start_experiment.sh 5 workloada 300 5 azure leader swapoff mem
./start_experiment.sh 5 workloada 300 6 azure leader swapon mem

./start_experiment.sh 5 workloada 300 1 azure noslow swapoff mem
./start_experiment.sh 5 workloads 300 1 azure noslow swapon mem

./start_experiment.sh 5 workloada 300 1 azure follower swapoff mem
./start_experiment.sh 5 workloada 300 2 azure follower swapoff mem
./start_experiment.sh 5 workloada 300 5 azure follower swapoff mem
./start_experiment.sh 5 workloada 300 6 azure follower swapon mem
