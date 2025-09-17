# Variables de configuration du projet DevSecOps
variable "project_id" {
  description = "GCP Project ID pour le déploiement"
  type        = string
  validation {
    condition     = length(var.project_id) > 0
    error_message = "Le Project ID ne peut pas être vide."
  }
}

variable "region" {
  description = "Région GCP pour le déploiement"
  type        = string
  default     = "europe-west1"
  validation {
    condition = contains([
      "europe-west1", 
      "europe-west3", 
      "europe-west4",
      "us-central1",
      "us-east1"
    ], var.region)
    error_message = "Région non supportée pour le déploiement sécurisé."
  }
}

variable "zone" {
  description = "Zone GCP pour les instances"
  type        = string
  default     = "europe-west1-b"
}

variable "environment" {
  description = "Environnement de déploiement"
  type        = string
  default     = "production"
  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "L'environnement doit être dev, staging ou production."
  }
}

# Configuration réseau
variable "vpc_name" {
  description = "Nom du VPC Zero Trust"
  type        = string
  default     = "zero-trust-network"
}

variable "private_subnet_cidr" {
  description = "CIDR du sous-réseau privé"
  type        = string
  default     = "10.0.1.0/24"
  validation {
    condition     = can(cidrhost(var.private_subnet_cidr, 0))
    error_message = "Le CIDR doit être un bloc réseau valide."
  }
}

variable "bastion_subnet_cidr" {
  description = "CIDR du sous-réseau bastion"
  type        = string
  default     = "10.0.2.0/24"
}

# Configuration des instances
variable "bastion_machine_type" {
  description = "Type de machine pour le bastion"
  type        = string
  default     = "e2-micro"
}

variable "k8s_master_machine_type" {
  description = "Type de machine pour les masters K8s"
  type        = string
  default     = "e2-standard-2"
  validation {
    condition = contains([
      "e2-standard-2",
      "e2-standard-4", 
      "e2-standard-8",
      "n1-standard-2",
      "n1-standard-4"
    ], var.k8s_master_machine_type)
    error_message = "Type de machine non adapté pour Kubernetes master."
  }
}

variable "k8s_worker_machine_type" {
  description = "Type de machine pour les workers K8s"
  type        = string
  default     = "e2-standard-2"
}

variable "k8s_master_count" {
  description = "Nombre de masters Kubernetes (HA)"
  type        = number
  default     = 3
  validation {
    condition     = var.k8s_master_count >= 1 && var.k8s_master_count <= 5
    error_message = "Le nombre de masters doit être entre 1 et 5."
  }
}

variable "k8s_worker_count" {
  description = "Nombre de workers Kubernetes"
  type        = number
  default     = 2
  validation {
    condition     = var.k8s_worker_count >= 1 && var.k8s_worker_count <= 10
    error_message = "Le nombre de workers doit être entre 1 et 10."
  }
}

# Configuration de sécurité
variable "allowed_ssh_cidrs" {
  description = "CIDRs autorisés pour l'accès SSH au bastion"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # À restreindre en production
}

variable "enable_tetragon" {
  description = "Activer Tetragon pour runtime security"
  type        = bool
  default     = true
}

variable "enable_audit_logging" {
  description = "Activer l'audit logging détaillé"
  type        = bool
  default     = true
}

variable "disk_size_gb" {
  description = "Taille des disques système en GB"
  type        = number
  default     = 50
  validation {
    condition     = var.disk_size_gb >= 20 && var.disk_size_gb <= 500
    error_message = "La taille du disque doit être entre 20 et 500 GB."
  }
}

variable "disk_type" {
  description = "Type de disque (performance vs coût)"
  type        = string
  default     = "pd-standard"
  validation {
    condition = contains([
      "pd-standard",
      "pd-ssd", 
      "pd-balanced"
    ], var.disk_type)
    error_message = "Type de disque non supporté."
  }
}

# Configuration des images
variable "golden_image_family" {
  description = "Famille d'images golden construites par Packer"
  type        = string
  default     = "golden-image-k8s"
}

variable "source_image_project" {
  description = "Projet source pour les images de base"
  type        = string
  default     = "ubuntu-os-cloud"
}

# Tags et labels
variable "common_tags" {
  description = "Tags communs à appliquer à toutes les ressources"
  type        = list(string)
  default = [
    "zero-trust",
    "devsecops", 
    "kubernetes",
    "production"
  ]
}

variable "additional_labels" {
  description = "Labels additionnels pour les ressources"
  type        = map(string)
  default     = {}
}

# Configuration monitoring
variable "enable_monitoring" {
  description = "Activer le monitoring avancé des ressources"
  type        = bool
  default     = true
}

variable "monitoring_retention_days" {
  description = "Durée de rétention des logs de monitoring"
  type        = number
  default     = 30
}

# Variables d'output
variable "output_bastion_ip" {
  description = "Exposer l'IP publique du bastion dans les outputs"
  type        = bool
  default     = true
}