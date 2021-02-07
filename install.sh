sudo apt autoremove -y --allow-change-held-packages docker-ce kubelet kubeadm kubectl docker-ce docker-ce-cli

cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
br_netfilter
EOF

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sudo sysctl --system

sudo apt install -y --allow-change-held-packages docker-ce=5:19.03.11~3-0~ubuntu-bionic docker-ce-cli=5:19.03.11~3-0~ubuntu-bionic kubelet=1.19.7-00 kubeadm=1.19.7-00 kubectl=1.19.7-00

sudo apt-mark hold docker-ce docker-ce-cli kubelet kubeadm kubectl

sudo kubeadm config images pull

cpe=$(hostname -I | awk -F " " '{ print $1 }')

sudo kubeadm init --control-plane-endpoint=${cpe}--pod-network-cidr=10.244.0.0/16

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

kubectl taint nodes --all node-role.kubernetes.io/master-

kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml

