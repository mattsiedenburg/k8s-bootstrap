sudo apt-mark unhold docker-ce-cli docker-ce kubelet kubeadm kubectl

sudo apt autoremove -y --allow-change-held-packages docker-ce kubelet kubeadm kubectl docker-ce docker-ce-cli


cpe=$(hostname -I | awk -F " " '{ print $1 }')
kubectl drain $(hostname) --delete-emptydir-data --force --ignore-daemonsets

sudo kubeadm reset -f

sudo rm -rf ~/.kube

docker kill $(docker ps -qa)
docker rm $(docker ps -qa)
docker volume prune -f
docker network prune -f

sudo systemctl stop docker
sudo systemctl stop kubelet

wait 10

sudo rm -rf /etc/kubernetes/
sudo rm -rf /var/lib/kubelet/
sudo rm -rf /var/lib/cni/
sudo rm -rf /etc/cni/
sudo rm -rf /var/lib/etcd/
sudo rm -rf /var/lib/docker/
sudo rm -rf /opt/cni/
sudo rm -rf /opt/containerd/

sudo systemctl start docker
sudo systemctl start kubelet

sudo iptables -F
sudo iptables -t nat -F
sudo iptables -t mangle -F
sudo iptables -X


sudo iptables -P INPUT ACCEPT
sudo iptables -P OUTPUT ACCEPT
sudo iptables -P FORWARD ACCEPT
