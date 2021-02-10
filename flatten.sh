#!/bin/bash
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

helm repo remove rancher-stable jetstack portainer traefik

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
rm -rf /var/lib/longhorn/


iptables -F
iptables -t nat -F
iptables -t mangle -F
iptables -X


iptables -P INPUT ACCEPT
iptables -P OUTPUT ACCEPT
iptables -P FORWARD ACCEPT


apt-mark unhold docker-ce-cli docker-ce kubelet kubeadm kubectl helm containerd.io
apt-get autoremove -y --purge --allow-change-held-packages kubelet kubeadm kubectl docker-ce docker-ce-cli containerd.io helm

add-apt-repository -r "deb [arch=amd64] https://download.docker.com/linux/ubuntu bionic stable"
rm -rf /etc/apt/sources.list.d/helm-stable-debian.list*
rm -rf /etc/apt/sources.list.d/kubernetes.list*

sudo apt-key del "9DC8 5822 9FC7 DD38 854A  E2D8 8D81 803C 0EBF CD88"
sudo apt-key del "81BF 832E 2F19 CD2A A047  1959 294A C482 7C1A 168A"
sudo apt-key del "54A6 47F9 048D 5688 D7DA  2ABE 6A03 0B21 BA07 F4FB"
sudo apt-key del "59FE 0256 8272 69DC 8157  8F92 8B57 C5C2 836F 4BEB"