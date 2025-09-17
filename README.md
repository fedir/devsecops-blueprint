# Blueprint DevSecOps Zero Trust - Architecture de Référence

## Vue d'ensemble Architecture

**Objectif** : Démontrer une maîtrise complète de la sécurité dans une chaîne CI/CD "Zero Trust" pour l'industrie de défense.

**Contraintes techniques** :
- Infrastructure simulée "on-premise" sur GCP (VMs uniquement, pas de GKE)
- Réseau fortifié avec politique "deny by default"
- 3 dépôts Git séparés pour la séparation des responsabilités
- Supply chain sécurisée avec signature d'images

## Structure du Projet

```
devsecops-blueprint/
├── setup.sh                    # Script d'initialisation
├── cleanup.sh                  # Script de nettoyage
├── README.md                   # Ce guide
├── infrastructure-repo/        # Code Terraform & Packer
│   ├── image.pkr.hcl
│   ├── main.tf
│   ├── backend.tf
│   └── variables.tf
├── application-repo/           # Code Go & Pipeline CI
│   ├── main.go
│   ├── Dockerfile
│   └── .gitlab-ci.yml
└── gitops-repo/               # Manifestes K8s & Policies
    ├── app/
    │   ├── deployment.yaml
    │   ├── service.yaml
    │   └── networkpolicy.yaml
    ├── security/
    │   ├── cosign-public-key.yaml
    │   ├── kyverno-policy.yaml
    │   └── tetragon-policies.yaml
    ├── monitoring/
    │   └── tetragon-config.yaml
    └── argocd/
        └── application.yaml
```

## Étape 1 : Initialisation

```bash
# Lancez depuis Google Cloud Shell
./setup.sh
```

Le script vous demandera :
- Votre Project ID GCP
- Votre nom d'utilisateur GitLab

## Étape 2 : Configuration GitLab

1. **Créez 3 dépôts privés sur gitlab.com** :
   - `infrastructure-repo`
   - `application-repo` 
   - `gitops-repo`

2. **Poussez le code** :
```bash
# Pour chaque dossier
cd infrastructure-repo
git init && git remote add origin https://gitlab.com/VOTRE_USERNAME/infrastructure-repo.git
git add . && git commit -m "Initial infrastructure setup"
git push -u origin main

# Répétez pour application-repo et gitops-repo
```

3. **Configurez les variables CI/CD dans application-repo** :
   - `GCP_PROJECT_ID` : Votre Project ID
   - `GITOPS_REPO_URL` : URL du dépôt gitops-repo
   - `GITLAB_TOKEN` : Token GitLab avec accès aux dépôts

4. **Ajoutez les Deploy Keys** dans gitops-repo pour permettre l'écriture depuis application-repo.

## Étape 3 : Déploiement Infrastructure

```bash
cd infrastructure-repo
terraform init
terraform plan
terraform apply
```

## Étape 4 : Lancement Pipeline

La pipeline dans `application-repo` s'exécute automatiquement et :
1. Analyse le code (SAST, SCA, Secret Detection)
2. Construit l'image Docker distroless
3. Génère les clés Cosign
4. Signe l'image
5. Pousse la clé publique vers gitops-repo
6. Met à jour les manifestes K8s

## Architecture de Sécurité

### Réseau Zero Trust
- VPC isolé sans sous-réseaux automatiques
- Règles pare-feu "deny all" par défaut
- Accès uniquement via bastion host

### Supply Chain Security
- Images signées avec Cosign
- Policies Kyverno pour validation des signatures
- Conteneurs distroless non-root

### Secrets Management
- Simulation d'intégration HashiCorp Vault
- Annotations pour injection de secrets
- Séparation des secrets par environnement

### Runtime Security
- **Tetragon eBPF** : Observabilité temps réel du comportement des conteneurs
- **Security Policies** : Détection d'anomalies comportementales
- **Threat Detection** : Monitoring des appels système suspects
- **Compliance Monitoring** : Audit continu des exécutions


