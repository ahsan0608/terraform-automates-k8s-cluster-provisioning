#!/bin/bash

# Decode the sudo password (passed as an argument)
PASSWORD=$(echo "$1" | base64 --decode | tr -d '\n')

# Allow the user to run sudo commands without a password temporarily
echo "$PASSWORD" | sudo -S bash -c "echo 'rnd ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/temp_sudoers"

# Reset any previous Kubernetes setup
sudo kubeadm reset -f
sudo systemctl stop kubelet
sudo systemctl stop containerd
sudo rm -rf /etc/cni/net.d
sudo iptables -F && sudo iptables -X

# Remove old iptables NAT and Flannel configuration to prevent conflicts
sudo iptables -t nat -F
sudo iptables -t nat -X
sudo ip link delete cni0 || true
sudo ip link delete flannel.1 || true
sudo rm -rf /var/lib/cni/
sudo rm -rf /var/lib/kubelet/*
sudo rm -rf /etc/kubernetes/manifests/

# Update package lists and install dependencies
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg

# Install containerd and necessary components
sudo apt-get install -y containerd
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd

# Configure DNS Resolver
sudo bash -c "echo -e 'nameserver 8.8.8.8\nnameserver 1.1.1.1' > /etc/resolv.conf"
sudo systemctl restart systemd-resolved

# Download and configure Kubernetes components
sudo mkdir -p /etc/apt/keyrings
sudo rm -f /etc/apt/keyrings/kubernetes-apt-keyring.gpg
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

# Update package list and install Kubernetes components
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl --option=Dpkg::Options::="--force-confnew" --option=Dpkg::Options::="--force-confdef"
sudo apt-mark hold kubelet kubeadm kubectl

# Ensure kubelet and containerd services are running
sudo systemctl daemon-reload
sudo systemctl start containerd
sudo systemctl start kubelet
sudo systemctl enable kubelet

# Initialize the Kubernetes master node
sudo kubeadm init --apiserver-advertise-address=$(hostname -I | awk '{print $1}') --pod-network-cidr=10.244.0.0/16

# Set up the Kubernetes configuration for the root user
mkdir -p $HOME/.kube
sudo cp -f /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Install Flannel as the Pod network
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml

# Wait for the Flannel network to be ready
echo "Waiting for Flannel to be ready..."
for i in {1..10}; do
  FLANNEL_READY=$(kubectl -n kube-flannel get daemonset kube-flannel-ds -o jsonpath='{.status.numberReady}')
  if [ "$FLANNEL_READY" -ge 1 ]; then
    echo "Flannel is ready."
    break
  fi
  if [ "$i" -eq 10 ]; then
    echo "Flannel failed to become ready. Trying with Calico..."
    kubectl delete -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
    kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml
    break
  fi
  echo "Waiting for Flannel to be ready... ($i/10)"
  sleep 30
done

# Check if the API server is up
API_SERVER_STATUS=$(kubectl get pods -n kube-system | grep kube-apiserver | awk '{print $3}')
if [ "$API_SERVER_STATUS" != "Running" ]; then
    echo "Error: API server is not running. Exiting."
    exit 1
fi

# Check if kube-proxy is stable
KUBE_PROXY_STATUS=$(kubectl get pods -n kube-system | grep kube-proxy | awk '{print $3}')
if [ "$KUBE_PROXY_STATUS" != "Running" ]; then
    echo "Error: kube-proxy is not running. Exiting."
    exit 1
fi

# Ensure all essential Kubernetes components are running
kubectl get pods --all-namespaces

# Remove the temporary sudoers file
sudo rm -f /etc/sudoers.d/temp_sudoers

echo "Kubernetes master setup completed successfully!"
