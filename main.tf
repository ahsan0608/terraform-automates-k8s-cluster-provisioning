module "master" {
  source    = "./modules/master"
  master_ip = var.master_ip
  username  = var.usernames.master
  password  = var.passwords.master
}

module "workers" {
  source      = "./modules/workers"
  worker_ips  = var.worker_ips
  usernames   = [var.usernames.worker1]
  passwords   = [var.passwords.worker1]
  master_ip   = var.master_ip
  kubeadm_token = var.kubeadm_token
  ca_cert_hash = var.ca_cert_hash
}
