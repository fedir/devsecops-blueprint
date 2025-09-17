# Provider et variables
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "europe-west1"
}

variable "zone" {
  description = "GCP Zone"
  type        = string
  default     = "europe-west1-b"
}

# VPC Zero Trust
resource "google_compute_network" "zero_trust_vpc" {
  name                    = "zero-trust-network"
  auto_create_subnetworks = false
  description            = "Zero Trust VPC - Deny all by default"
}

resource "google_compute_subnetwork" "private_subnet" {
  name          = "private-subnet"
  ip_cidr_range = "10.0.1.0/24"
  region        = var.region
  network       = google_compute_network.zero_trust_vpc.id
  
  # Pas d'accès Internet direct
  private_ip_google_access = true
}

# Bastion Host - Point d'entrée unique
resource "google_compute_instance" "bastion" {
  name         = "bastion-host"
  machine_type = "e2-micro"
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "projects/ubuntu-os-cloud/global/images/ubuntu-2004-focal-v20231101"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.private_subnet.id
    access_config {
      # IP publique temporaire pour demo
    }
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }

  tags = ["bastion", "ssh-access"]
}

# Master nodes du cluster K8s simulé
resource "google_compute_instance" "k8s_masters" {
  count        = 3
  name         = "k8s-master-${count.index + 1}"
  machine_type = "e2-standard-2"
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "golden-image-k8s" # Image construite par Packer
      size  = 50
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.private_subnet.id
    # Pas d'IP publique - accès uniquement via bastion
  }

  tags = ["k8s-master", "internal-only"]

  # Métadonnées pour l'installation K8s
  metadata = {
    role = "master"
    cluster-name = "zero-trust-cluster"
  }
}

# Worker nodes
resource "google_compute_instance" "k8s_workers" {
  count        = 2
  name         = "k8s-worker-${count.index + 1}"
  machine_type = "e2-standard-2"
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "golden-image-k8s"
      size  = 50
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.private_subnet.id
  }

  tags = ["k8s-worker", "internal-only"]

  metadata = {
    role = "worker"
    cluster-name = "zero-trust-cluster"
    enable-tetragon = "true"
  }
}

# Règles de pare-feu Zero Trust
resource "google_compute_firewall" "deny_all_egress" {
  name      = "deny-all-egress"
  network   = google_compute_network.zero_trust_vpc.name
  direction = "EGRESS"
  priority  = 65534

  deny {
    protocol = "all"
  }

  destination_ranges = ["0.0.0.0/0"]
  description       = "Zero Trust: Deny all egress by default"
}

resource "google_compute_firewall" "allow_ssh_bastion" {
  name      = "allow-ssh-bastion"
  network   = google_compute_network.zero_trust_vpc.name
  direction = "INGRESS"
  priority  = 1000

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"] # À restreindre en prod
  target_tags   = ["ssh-access"]
  description   = "Allow SSH to bastion only"
}

resource "google_compute_firewall" "allow_internal" {
  name      = "allow-internal-communication"
  network   = google_compute_network.zero_trust_vpc.name
  direction = "INGRESS"
  priority  = 1000

  allow {
    protocol = "tcp"
  }

  allow {
    protocol = "udp"
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = ["10.0.1.0/24"]
  description   = "Allow internal subnet communication"
}

# Outputs
output "bastion_external_ip" {
  value = google_compute_instance.bastion.network_interface[0].access_config[0].nat_ip
}

output "master_internal_ips" {
  value = google_compute_instance.k8s_masters[*].network_interface[0].network_ip
}