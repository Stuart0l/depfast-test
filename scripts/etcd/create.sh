set -ex
for i in $(seq 5 9); do
	# ssh -o StrictHostKeyChecking=no 10.0.0.$i "\
	# 	sudo sh -c ' wget https://golang.org/dl/go1.15.5.linux-amd64.tar.gz; \
	# 	sudo tar -C /usr/local -xzf go1.15.5.linux-amd64.tar.gz; \
	# 	export PATH=$PATH:/usr/local/go/bin; \
	# 	echo "PATH=\$PATH:/usr/local/go/bin" >> .bashrc ; \
	# 	echo "PATH=\$PATH:/usr/local/go/bin" >> .bash_profile ;'"
	scp -o  StrictHostKeyChecking=no ~/inf 10.0.0.$i:~
	# ssh -o StrictHostKeyChecking=no 10.0.0.$i "./install_etcd.sh"
	# ssh -o StrictHostKeyChecking=no 10.0.0.$i "sudo apt-get install htop -y"
	# user=$USER
done 