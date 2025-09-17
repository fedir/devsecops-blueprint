# Golden Image Packer pour infrastructure immuable
variable "project_id" {
  type        = string
  description = "GCP Project ID"
}

variable "zone" {
  type    = string
  default = "europe-west1-b"
}

variable "source_image_family" {
  type    = string
  default = "ubuntu-2004-lts"
}

variable "image_name" {
  type    = string
  default = "golden-image-k8s"
}

# Configuration Packer
packer {
  required_plugins {
    googlecompute = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/googlecompute"
    }
  }
}

# Source image Ubuntu 20.04 durcie
source "googlecompute" "ubuntu" {
  project_id              = var.project_id
  source_image_family     = var.source_image_family
  source_image_project_id = ["ubuntu-os-cloud"]
  zone                    = var.zone
  
  # Configuration de la VM de build
  machine_type = "e2-standard-2"
  disk_size    = 20
  disk_type    = "pd-ssd"
  
  # Configuration réseau sécurisée
  network          = "default"
  subnetwork       = "default"
  use_internal_ip  = false
  
  # Image de sortie
  image_name        = "${var.image_name}-{{timestamp}}"
  image_description = "Golden image K8s durcie - Build {{timestamp}}"
  image_family      = var.image_name
  
  # Tags pour organisation
  image_labels = {
    environment = "production"
    team        = "devsecops"
    compliance  = "defense"
    build_date  = "{{timestamp}}"
  }
  
  # SSH Configuration
  ssh_username = "packer"
  
  # Nettoyage automatique
  skip_create_image = false
}

# Build process avec durcissement sécuritaire
build {
  name = "golden-k8s-image"
  sources = ["source.googlecompute.ubuntu"]
  
  # Mise à jour du système et installation des prérequis
  provisioner "shell" {
    inline = [
      "echo '=== System Hardening & Updates ==='",
      "sudo apt-get update -y",
      "sudo apt-get upgrade -y",
      "sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release",
      
      # Installation Docker (runtime K8s)
      "echo '=== Installing Docker ==='",
      "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg",
      "echo \"deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable\" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null",
      "sudo apt-get update -y",
      "sudo apt-get install -y docker-ce docker-ce-cli containerd.io",
      
      # Installation Kubernetes
      "echo '=== Installing Kubernetes ==='",
      "curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -",
      "echo 'deb https://apt.kubernetes.io/ kubernetes-xenial main' | sudo tee /etc/apt/sources.list.d/kubernetes.list",
      "sudo apt-get update -y",
      "sudo apt-get install -y kubelet=1.28.0-00 kubeadm=1.28.0-00 kubectl=1.28.0-00",
      "sudo apt-mark hold kubelet kubeadm kubectl",
      
      # Outils de sécurité
      "echo '=== Installing Security Tools ==='",
      "sudo apt-get install -y fail2ban ufw auditd",
      
      # Installation Tetragon (préparation)
      "echo '=== Preparing Tetragon ==='",
      "sudo mkdir -p /opt/tetragon",
      "sudo mkdir -p /var/log/tetragon",
    ]
  }
  
  # Configuration sécuritaire du système
  provisioner "file" {
    content = <<EOF
# Configuration Docker sécurisée
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2",
  "storage-opts": [
    "overlay2.override_kernel_check=true"
  ],
  "live-restore": true,
  "userland-proxy": false,
  "no-new-privileges": true,
  "seccomp-profile": "/etc/docker/seccomp.json",
  "default-ulimits": {
    "nofile": {
      "Hard": 64000,
      "Name": "nofile",
      "Soft": 64000
    }
  }
}
EOF
    destination = "/tmp/daemon.json"
  }
  
  # Script de durcissement système
  provisioner "file" {
    content = <<EOF
#!/bin/bash
set -euo pipefail

echo "=== Security Hardening ==="

# Configuration Docker sécurisée
sudo mkdir -p /etc/docker
sudo cp /tmp/daemon.json /etc/docker/daemon.json

# Configuration du pare-feu
sudo ufw --force enable
sudo ufw default deny incoming
sudo ufw default deny outgoing
sudo ufw allow ssh
sudo ufw allow 6443/tcp  # K8s API
sudo ufw allow 2379:2380/tcp  # etcd
sudo ufw allow 10250/tcp # kubelet
sudo ufw allow 10251/tcp # kube-scheduler
sudo ufw allow 10252/tcp # kube-controller-manager

# Configuration audit
sudo systemctl enable auditd
sudo systemctl start auditd

# Durcissement SSH
sudo sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config

# Configuration fail2ban
sudo systemctl enable fail2ban
sudo systemctl start fail2ban

# Désactivation des services non nécessaires
sudo systemctl disable snapd
sudo systemctl stop snapd

# Configuration kernel parameters sécurisés
cat << 'KERNEL_EOF' | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
# Sécurité réseau
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
KERNEL_EOF

# Application des paramètres
sudo modprobe overlay
sudo modprobe br_netfilter
sudo sysctl --system

echo "=== Hardening Complete ==="
EOF
    destination = "/tmp/harden.sh"
  }
  
  # Application du durcissement
  provisioner "shell" {
    inline = [
      "chmod +x /tmp/harden.sh",
      "sudo /tmp/harden.sh",
    ]
  }
  
  # Nettoyage final
  provisioner "shell" {
    inline = [
      "echo '=== Final Cleanup ==='",
      "sudo apt-get autoremove -y",
      "sudo apt-get autoclean",
      "sudo rm -rf /tmp/*",
      "sudo rm -rf /var/tmp/*",
      "sudo truncate -s 0 /var/log/*log",
      "history -c && history -w",
      "sudo sync",
      "echo 'Golden image build complete!'"
    ]
  }
}