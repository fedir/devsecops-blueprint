#!/bin/bash
set -euo pipefail

echo "=== DevSecOps Zero Trust Setup ==="

# Collecte des informations
read -p "Votre Project ID GCP: " PROJECT_ID
read -p "Votre username GitLab: " GITLAB_USER

# Configuration gcloud
gcloud config set project $PROJECT_ID
export PROJECT_ID=$PROJECT_ID

# Activation des APIs
echo "Activation des APIs GCP..."
gcloud services enable compute.googleapis.com
gcloud services enable cloudbuild.googleapis.com
gcloud services enable artifactregistry.googleapis.com

# Création du bucket Terraform backend
echo "Création du backend Terraform..."
gsutil mb gs://$PROJECT_ID-terraform-state || true

# Création du registry
echo "Création d'Artifact Registry..."
gcloud artifacts repositories create app-images \
    --repository-format=docker \
    --location=europe-west1 || true

# Configuration des variables d'environnement
cat > .env << EOF
export PROJECT_ID=$PROJECT_ID
export GITLAB_USER=$GITLAB_USER
export ARTIFACT_REGISTRY=europe-west1-docker.pkg.dev/$PROJECT_ID/app-images
EOF

echo "Setup terminé ! Sourcez le fichier .env : source .env"