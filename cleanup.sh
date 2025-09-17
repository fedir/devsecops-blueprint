#!/bin/bash
set -euo pipefail

echo "=== Nettoyage des ressources DevSecOps ==="

# Chargement des variables
source .env 2>/dev/null || {
    echo "Fichier .env non trouvé. Veuillez spécifier PROJECT_ID:"
    read -p "Project ID: " PROJECT_ID
}

echo "Destruction de l'infrastructure Terraform..."
cd infrastructure-repo
terraform destroy -auto-approve -var="project_id=$PROJECT_ID"

echo "Nettoyage du bucket Terraform..."
gsutil rm -r gs://$PROJECT_ID-terraform-state/ || echo "Bucket déjà supprimé"

echo "Suppression d'Artifact Registry..."
gcloud artifacts repositories delete app-images \
    --location=europe-west1 \
    --quiet || echo "Registry déjà supprimé"

echo "Nettoyage terminé ! 🧹"
echo "N'oubliez pas de supprimer manuellement les dépôts GitLab si nécessaire."