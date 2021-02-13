#!/bin/bash
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

echo "Uninstalling packages"
apt-get autoremove -y --purge --allow-change-held-packages docker-ce kubelet kubeadm kubectl docker-ce docker-ce-cli docker docker-engine docker.io containerd runc
echo "Installing packages"
apt-get install -y apt-transport-https ca-certificates curl gnupg-agent software-properties-common

echo "Getting apt keys for docker, kubernetes and helm"
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
curl https://baltocdn.com/helm/signing.asc | sudo apt-key add -

echo "Adding repos for docker, kubernetes and helm"
add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"

cat <<EOF | sudo tee /etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF

echo "deb https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list

echo "Installing docker, docker CLI, kubeadm, kubelet, kubectl and helm"
apt-get update

apt-get install -y --allow-change-held-packages docker-ce=5:19.03.11~3-0~ubuntu-bionic docker-ce-cli=5:19.03.11~3-0~ubuntu-bionic kubelet=1.19.7-00 kubeadm=1.19.7-00 kubectl=1.19.7-00 containerd.io helm
apt-mark hold docker-ce docker-ce-cli kubelet kubeadm kubectl containerd.io helm

echo "Adding user to docker group"
usermod -aG docker $(logname)

echo "Configuring network bridge for kubernetes"
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
br_netfilter
EOF

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sysctl --system

echo "Fetching kubelet docker images"
kubeadm config images pull

echo "Initializing kubenetes cluster"
kubeadm init --control-plane-endpoint=$(hostname) --pod-network-cidr=10.244.0.0/16

echo "Copying kube config file"
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown -R $(logname):$(id $(logname) -gn) $HOME/.kube

echo "Tainting node for worker role"
kubectl taint nodes --all node-role.kubernetes.io/master-

echo  "Installing Flannel"
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml

echo "Installing longhorn"
kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/master/deploy/longhorn.yaml

echo "Configuring configmap kube-proxy for MetalLB"
kubectl get configmap kube-proxy -n kube-system -o yaml | \
   sed -e "s/strictARP: false/strictARP: true/" | \
   kubectl apply -f - -n kube-system

echo "Installing MetalLB"
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/main/manifests/namespace.yaml
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/main/manifests/metallb.yaml
kubectl create secret generic -n metallb-system memberlist --from-literal=secretkey="$(openssl rand -base64 128)"

# helm repo add bitnami https://charts.bitnami.com/bitnami
# helm repo update
# helm install metal-lb bitnami/metallb

echo "Configuring MetalLB"
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  namespace: metallb-system
  name: config
data:
  config: |
    address-pools:
    - name: default
      protocol: layer2
      addresses:
      - 192.168.1.10-192.168.1.49
EOF

echo "Installing nginx ingress controller"
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/static/provider/baremetal/deploy.yaml
# helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
# helm repo update
# helm install ingress-nginx ingress-nginx/ingress-nginx

echo "Installing Prometheus and Grafana"
kubectl create namespace monitoring
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install prometheus prometheus-community/kube-prometheus-stack -n monitoring

echo "Changing service/prometheus-kube-prometheus-prometheus, service/prometheus-grafana, longhorn-frontend and service/ingress-nginx-controller to type LoadBalancer"
kubectl get -n monitoring svc prometheus-kube-prometheus-prometheus -o yaml | \
sed -e "s/type: ClusterIP/type: LoadBalancer/" | \
kubectl apply -f - -n monitoring

kubectl get -n monitoring svc prometheus-grafana -o yaml | \
sed -e "s/type: ClusterIP/type: LoadBalancer/" | \
kubectl apply -f - -n monitoring

kubectl get -n longhorn-system svc longhorn-frontend -o yaml | \
sed -e "s/type: ClusterIP/type: LoadBalancer/" | \
kubectl apply -f - -n longhorn-system

kubectl get -n ingress-nginx svc ingress-nginx-controller -o yaml | \
sed -e "s/type: NodePort/type: LoadBalancer/" | \
kubectl apply -f - -n ingress-nginx

echo "Taking ownership of ${HOME}/.kube and ${HOME}/.config"
chown -R $(logname):$(id $(logname) -gn) $HOME/.kube
chown -R $(logname):$(id $(logname) -gn) $HOME/.config

# uninstall prometheus-community/kube-prometheus-stack
# helm uninstall prometheus -n monitoring
# kubectl delete crd prometheuses.monitoring.coreos.com
# kubectl delete crd prometheusrules.monitoring.coreos.com
# kubectl delete crd servicemonitors.monitoring.coreos.com
# kubectl delete crd podmonitors.monitoring.coreos.com
# kubectl delete crd alertmanagers.monitoring.coreos.com
# kubectl delete crd thanosrulers.monitoring.coreos.com
# kubectl delete crd alertmanagerconfigs.monitoring.coreos.com
# kubectl delete crd probes.monitoring.coreos.com