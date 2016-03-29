#!/bin/bash
set -o errexit
set -o nounset

# Check if running debian or redhat based OS
if ! type "apt-get" 2>&1 > /dev/null; then
  OS="REDHAT"

cat > /etc/yum.repos.d/kubernetes.repo <<EOL
[virt7-docker-common-release]
name=virt7-docker-common-release
baseurl=http://cbs.centos.org/repos/virt7-docker-common-release/x86_64/os/
gpgcheck=0
EOL

yum -y install --enablerepo=virt7-docker-common-release kubernetes etcd

cat > /etc/kubernetes/config <<EOL
KUBE_ETCD_SERVERS="--etcd-servers=http://master.k8s:2379"
KUBE_LOGTOSTDERR="--logtostderr=true"
KUBE_LOG_LEVEL="--v=0"
KUBE_ALLOW_PRIV="--allow-privileged=false"
EOL

else
  OS="DEBIAN"
fi

if [ "$K8S_ROLE" == "MASTER" ]; then

  echo -e "${SCALR_INTERNAL_IP} master.k8s" >> /etc/hosts
  szradm queryenv set-global-variable scope=farm param-name=K8S_MASTER param-value="${SCALR_INTERNAL_IP}"

  if [ "$OS" == "REDHAT" ]; then

cat > /etc/kubernetes/apiserver <<EOL
KUBE_API_ADDRESS="--address=0.0.0.0"
KUBE_API_PORT="--port=8080"
KUBE_MASTER="--master=http://master.k8s:8080"
KUBELET_PORT="--kubelet-port=10250"
KUBE_SERVICE_ADDRESSES="--service-cluster-ip-range=10.254.0.0/16"
KUBE_API_ARGS=""
EOL

cat > /etc/etcd/etcd.conf <<EOL
ETCD_NAME=default
ETCD_DATA_DIR="/var/lib/etcd/default.etcd"
ETCD_LISTEN_CLIENT_URLS="http://0.0.0.0:2379"
ETCD_ADVERTISE_CLIENT_URLS="http://master.k8s:2379"
EOL

	for SERVICES in etcd kube-apiserver kube-controller-manager kube-scheduler; do
		systemctl restart $SERVICES
		systemctl enable $SERVICES
		systemctl status $SERVICES 
	done

    etcdctl mk /kubernetes.io/network/config '{"Network":"172.17.0.0/16"}'
  else
    echo "Ubuntu"
  fi


else

  echo -e "${K8S_MASTER} master.k8s" >> /etc/hosts

  if [ "$OS" == "REDHAT" ]; then

cat > /etc/kubernetes/kubelet <<EOL
KUBELET_ADDRESS="--address=0.0.0.0"
KUBELET_PORT="--port=10250"
KUBELET_HOSTNAME="--hostname-override=${SCALR_INTERNAL_IP}"
KUBELET_API_SERVER="--api-servers=http://master.k8s:8080"
KUBELET_ARGS=""
EOL

    yum -y install flannel

cat > /etc/sysconfig/flanneld <<EOL
FLANNEL_ETCD="http://${K8S_MASTER}:2379"
FLANNEL_ETCD_KEY="/kubernetes.io/network"
EOL

	for SERVICES in kube-proxy kubelet docker; do
    	systemctl restart $SERVICES
    	systemctl enable $SERVICES
    	systemctl status $SERVICES 
	done

  else
    echo "Ubuntu"
  fi

fi
