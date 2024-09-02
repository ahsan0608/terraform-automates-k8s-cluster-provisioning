variable "master_ip" {
  description = "IP address of the master node"
  type        = string
}

variable "username" {
  description = "Username for the master node SSH connection"
  type        = string
}

variable "password" {
  description = "Password for the master node (encoded in base64)"
  type        = string
}

resource "null_resource" "master_node" {
  connection {
    type        = "ssh"
    user        = var.username
    host        = var.master_ip
    private_key = file("~/.ssh/id_rsa")
  }

  provisioner "file" {
    source      = "${path.module}/scripts/init-master.sh"
    destination = "/tmp/init-master.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/init-master.sh",
      "/tmp/init-master.sh ${var.password}"
    ]
  }

  lifecycle {
    create_before_destroy = true
  }
}
