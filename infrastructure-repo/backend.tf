# Configuration du backend Terraform distant sécurisé
terraform {
  required_version = ">= 1.0"
  
  # Backend GCS avec chiffrement
  backend "gcs" {
    bucket                      = "${var.project_id}-terraform-state"
    prefix                      = "devsecops/infrastructure"
    impersonate_service_account = null
    
    # Sécurité du backend
    encryption_key = null  # Utilise le chiffrement par défaut de GCS
    storage_class  = "REGIONAL"
  }
  
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    
    google-beta = {
      source  = "hashicorp/google-beta" 
      version = "~> 5.0"
    }
    
    random = {
      source  = "hashicorp/random"
      version = "~> 3.4"
    }
    
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

# Configuration des providers
provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
  
  # Configuration par défaut des ressources
  default_labels = {
    environment   = "production"
    team         = "devsecops" 
    managed_by   = "terraform"
    compliance   = "defense"
    project      = var.project_id
  }
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

# Génération d'IDs aléatoires pour uniqueness
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# Configuration locale pour cohérence
locals {
  # Labels communs pour toutes les ressources
  common_labels = {
    environment     = "production"
    team           = "devsecops"
    managed_by     = "terraform"
    compliance     = "defense"
    security_level = "high"
    created_date   = formatdate("YYYY-MM-DD", timestamp())
  }
  
  # Naming convention
  name_prefix = "zt-${var.environment}"  # Zero Trust prefix
  
  # Configuration réseau
  vpc_cidr = "10.0.0.0/16"
  subnets = {
    private = {
      cidr = "10.0.1.0/24"
      name = "${local.name_prefix}-private"
    }
    bastion = {
      cidr = "10.0.2.0/24" 
      name = "${local.name_prefix}-bastion"
    }
  }
}