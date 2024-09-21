variable "master_ip" {
  description = "IP address of the master node"
  default     = ""
}

variable "worker_ips" {
  description = "List of IP addresses of worker nodes"
  type        = list(string)
  default     = ["",""]
}

variable "usernames" {
  description = "List of usernames for the nodes"
  type        = map(string)
  default     = {
    master  = "db"
    worker1 = "monitoring"
  }
}

variable "passwords" {
  description = "List of passwords for the nodes"
  type        = map(string)
}

variable "kubeadm_token" {
  description = "Kubeadm join token for worker nodes"
}

variable "ca_cert_hash" {
  description = "Discovery token CA cert hash for worker nodes"
}
