#!/bin/bash

# Decode the sudo password (passed as an argument)
PASSWORD=$(echo "$1" | base64 --decode)

# Debugging: Print the password to confirm it's passed correctly (remove in production)
echo "DEBUG: Password is: $PASSWORD"

# Set the environment to non-interactive to avoid prompts
export DEBIAN_FRONTEND=noninteractive

# Allow the user to run sudo commands without a password temporarily
echo "$PASSWORD" | sudo -S bash -c "echo '$USER ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/temp_sudoers"

# Update package lists and install dependencies
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg

# Install containerd and necessary components
sudo apt-get install -y containerd

# Create containerd configuration file
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml

# Restart containerd to apply changes and ensure it's running
sudo systemctl restart containerd
sudo systemctl enable containerd

# Verify containerd is running
if systemctl is-active --quiet containerd; then
  echo "Containerd is running."
else
  echo "Error: Containerd failed to start. Exiting."
  exit 1
fi

# Create directory for apt keyrings if it doesn't exist
sudo mkdir -p /etc/apt/keyrings

# Download the public signing key for the Kubernetes package repositories
sudo rm -f /etc/apt/keyrings/kubernetes-apt-keyring.gpg # Ensure no prompt by deleting the file first
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# Add the Kubernetes apt repository
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

# Update package list and install Kubernetes components
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl --option=Dpkg::Options::="--force-confnew" --option=Dpkg::Options::="--force-confdef"
sudo apt-mark hold kubelet kubeadm kubectl

# Join the worker node to the Kubernetes cluster
JOIN_CMD="sudo kubeadm join ${2}:6443 --token ${3} --discovery-token-ca-cert-hash sha256:${4}"
echo "Executing join command: $JOIN_CMD"

if $JOIN_CMD; then
  echo "Node successfully joined the cluster."
else
  echo "Error: Failed to join the node to the cluster. Exiting."
  exit 1
fi

# Remove the temporary sudoers file
sudo rm -f /etc/sudoers.d/temp_sudoers
