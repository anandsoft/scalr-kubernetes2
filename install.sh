#!/bin/bash
set -o errexit
set -o nounset

# Send anonymous usage statistics to Scalr. Comment the next line to disable.
curl "http://tools.scalr.club/counter/hit.php?id=4" || true

# Check if running debian or redhat based OS
if ! type "apt-get" 2>&1 > /dev/null; then
  OS="REDHAT"
else
  OS="DEBIAN"
fi

if [ "$K8S_ROLE" == "MASTER" ]; then

  if [ "$OS" == "REDHAT" ]; then
    yum -y install etcd kubernetes
    sed -i 's/ETCD_LISTEN_CLIENT_URLS="http:\/\/localhost:2379"/ETCD_LISTEN_CLIENT_URLS="http:\/\/0.0.0.0:2379"/g' /etc/etcd/etcd.conf
    sed -i 's/KUBE_API_ADDRESS="--address=127.0.0.1"/KUBE_API_ADDRESS="--address=0.0.0.0"/g' /etc/kubernetes/apiserver

    for SERVICES in etcd kube-apiserver kube-controller-manager kube-scheduler; do 
      systemctl restart $SERVICES
      systemctl enable $SERVICES
      systemctl status $SERVICES 
    done

    etcdctl mk /atomic.io/network/config '{"Network":"172.17.0.0/16"}'
  else
    echo "Ubuntu"
  fi

  szradm queryenv set-global-variable scope=farm param-name=K8S_MASTER param-value="${SCALR_INTERNAL_IP}"

else

  if [ "$OS" == "REDHAT" ]; then
    yum -y install flannel kubernetes

    sed -i "s/FLANNEL_ETCD=\"http:\/\/127.0.0.1:2379\"/FLANNEL_ETCD=\"http:\/\/${K8S_MASTER}:2379\"/g" /etc/sysconfig/flanneld
    sed -i "s/KUBE_MASTER=\"--master=http:\/\/127.0.0.1:8080\"/KUBE_MASTER=\"--master=http:\/\/${K8S_MASTER}:8080\"/g" /etc/kubernetes/config
    echo 'KUBELET_PORT="--port=10250"' >> /etc/kubernetes/kubelet
    sed -i "s/KUBELET_HOSTNAME=\"--hostname_override=127.0.0.1\"/KUBELET_HOSTNAME=\"--hostname_override=${SCALR_INTERNAL_IP}\"/g" /etc/kubernetes/kubelet
    sed -i "s/KUBELET_API_SERVER=\"--api_servers=http:\/\/127.0.0.1:8080\"/KUBELET_API_SERVER=\"--api_servers=http:\/\/${K8S_MASTER}:8080\"/g" /etc/kubernetes/kubelet

    for SERVICES in kube-proxy kubelet docker flanneld; do 
      systemctl restart $SERVICES
      systemctl enable $SERVICES
      systemctl status $SERVICES 
    done

  else
    echo "Ubuntu"
  fi

fi

