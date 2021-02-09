#!/bin/bash
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

apt-get autoremove -y --purge --allow-change-held-packages docker-ce kubelet kubeadm kubectl docker-ce docker-ce-cli docker docker-engine docker.io containerd runc
apt-get install -y apt-transport-https ca-certificates curl gnupg-agent software-properties-common

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"

curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
cat <<EOF | sudo tee /etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF

curl https://baltocdn.com/helm/signing.asc | sudo apt-key add -
echo "deb https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list

apt-get update

apt-get install -y --allow-change-held-packages docker-ce=5:19.03.11~3-0~ubuntu-bionic docker-ce-cli=5:19.03.11~3-0~ubuntu-bionic kubelet=1.19.7-00 kubeadm=1.19.7-00 kubectl=1.19.7-00 containerd.io helm
apt-mark hold docker-ce docker-ce-cli kubelet kubeadm kubectl containerd.io helm

usermod -aG docker $(logname)

cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
br_netfilter
EOF

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sysctl --system

kubeadm config images pull

kubeadm init --control-plane-endpoint=$(hostname) --pod-network-cidr=10.244.0.0/16

mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown -R $(logname):$(id $(logname) -gn) $HOME/.kube

kubectl taint nodes --all node-role.kubernetes.io/master-

kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/v1.1.0/deploy/longhorn.yaml

watch kubectl get all --all-namespaces