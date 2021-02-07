#!/bin/bash
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

if [[ $(which kubectl) ]]; then
    cpe=$(hostname -I | awk -F " " '{ print $1 }')
    kubectl drain $(hostname) --delete-emptydir-data --force --ignore-daemonsets
else
    echo "Could not find kubectl"
fi

if [[ $(which kubeadm) ]]; then
    kubeadm reset -f
else
    echo "Could not find kubeadm"
fi


if [[ $(which docker) ]]; then
    docker kill $(docker ps -qa)
    docker rm $(docker ps -qa)
    docker volume prune -f
    docker network prune -f
else
    echo "Could not find docker"
fi


systemctl stop docker
systemctl stop kubelet

rm -rf ~/.kube
rm -rf /etc/kubernetes/
rm -rf /var/lib/kubelet/
rm -rf /var/lib/cni/
rm -rf /etc/cni/
rm -rf /var/lib/etcd/
rm -rf /var/lib/docker/
rm -rf /opt/cni/
rm -rf /opt/containerd/
rm -rf /usr/libexec/kubernetes/


iptables -F
iptables -t nat -F
iptables -t mangle -F
iptables -X


iptables -P INPUT ACCEPT
iptables -P OUTPUT ACCEPT
iptables -P FORWARD ACCEPT


systemctl start docker
systemctl start kubelet

apt-mark unhold docker-ce-cli docker-ce kubelet kubeadm kubectl
apt autoremove -y --allow-change-held-packages docker-ce kubelet kubeadm kubectl docker-ce docker-ce-cli


