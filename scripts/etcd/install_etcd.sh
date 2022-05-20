set -ex

ETCD_VER=v3.4.16

# choose either URL
GITHUB_URL=https://github.com/etcd-io/etcd/releases/download
DOWNLOAD_URL=${GITHUB_URL}

rm -f /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz
rm -rf /tmp/test-etcd && mkdir -p /tmp/test-etcd

curl -L ${DOWNLOAD_URL}/${ETCD_VER}/etcd-${ETCD_VER}-linux-amd64.tar.gz -o /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz
tar xzvf /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz -C /tmp/test-etcd --strip-components=1

# sudo cp /tmp/test-etcd/etcd* [YOUR_EXEC_DIR]
sudo mkdir -p /usr/local/bin/ && sudo cp /tmp/test-etcd/etcd* /usr/local/bin/

/tmp/test-etcd/etcd --version
ETCDCTL_API=3 /tmp/test-etcd/etcdctl version
