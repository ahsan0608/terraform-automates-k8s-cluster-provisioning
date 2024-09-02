variable "worker_ips" {
  description = "List of IP addresses of worker nodes"
  type        = list(string)
}

variable "usernames" {
  description = "List of usernames for the nodes"
  type        = list(string)
}

variable "passwords" {
  description = "List of passwords for the nodes (encoded in base64)"
  type        = list(string)
}

variable "master_ip" {
  description = "IP address of the master node"
  type        = string
}

variable "kubeadm_token" {
  description = "Kubeadm join token for worker nodes"
  type        = string
}

variable "ca_cert_hash" {
  description = "Discovery token CA cert hash for worker nodes"
  type        = string
}

resource "null_resource" "worker_nodes" {
  count = length(var.worker_ips)

  connection {
    type        = "ssh"
    user        = element(var.usernames, count.index)
    host        = element(var.worker_ips, count.index)
    private_key = file("~/.ssh/id_rsa")
  }

  provisioner "file" {
    source      = "${path.module}/scripts/init-worker.sh"
    destination = "/tmp/init-worker.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/init-worker.sh",
      "/tmp/init-worker.sh ${var.passwords[count.index]} ${var.master_ip} ${var.kubeadm_token} ${var.ca_cert_hash}"
    ]
  }

  lifecycle {
    create_before_destroy = true
  }
}
