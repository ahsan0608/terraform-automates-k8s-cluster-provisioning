This project automates the deployment of a Kubernetes cluster using Terraform. The cluster includes a master node and worker nodes, configured using a combination of Terraform scripts and a bash script (`init-master.sh`) for setting up the master node.

## Project Structure

- `main.tf`: Contains the Terraform configuration for provisioning the master and worker nodes.
- `variables.tf`: Defines the variables used in the Terraform configuration.
- `outputs.tf`: Outputs relevant information such as the master node IP and worker node IPs.
- `init-master.sh`: Bash script that configures the Kubernetes master node.

## Usage

### 1. Initialize Terraform:

```bash
terraform init
```

### 2. Review and modify the variables (if needed):

Edit the `variables.tf` file to customize the configuration according to your environment, such as IP addresses and SSH credentials.

### 3. Apply the Terraform configuration:

#### Set up the Master Node:

To set up the Kubernetes master node:

```bash
terraform apply -target=module.master
```

This command will:
- Provision the master node.
- Run the `init-master.sh` script on the master node to configure Kubernetes.
- Set up the Flannel network plugin (or Calico as a fallback).

#### Set up the Worker Nodes:

Before applying the worker node configuration, you must update the `terraform.tfvars` file with the following values from the master node setup:

- `kubeadm_token`: The token generated during the master node initialization.
- `ca_cert_hash`: The certificate hash for secure communication between the master and worker nodes.

After updating `terraform.tfvars`, apply the configuration to set up the worker nodes:

```bash
terraform apply -target=module.worker
```

This command will:
- Provision the worker nodes.
- Automatically join them to the Kubernetes cluster.

### 5. Verify the Kubernetes cluster:

After applying the configurations, SSH into the master node and verify the setup:

```bash
ssh user@<master-node-ip>
export KUBECONFIG=/etc/kubernetes/admin.conf
kubectl get nodes
kubectl get pods --all-namespaces
```
