# ecf-bilan-c6-infra

Infrastructure Terraform pour le déploiement d'un cluster AKS sur Azure, avec stockage chiffré (Key Vault + CMK), file shares NFS/SMB, et sauvegarde Velero. Le déploiement est piloté via GitHub Actions avec authentification OIDC (sans secret Azure stocké en clair).

## Structure du projet

```
ecf-bilan-c6-infra/
├── .github/
│   └── workflows/
│       ├── ci.yml                     # Pipeline CI (Validation, fmt & terraform plan)
│       └── workflow-dispatch.yml      # Déclenchement manuel des workflows GitHub Actions
├── modules/
│   ├── aks/                           # Module cluster Azure Kubernetes Service
│   │   ├── main.tf                    # Ressources du cluster, node pools et profils OIDC
│   │   ├── outputs.tf                 # Exportations (kube_config, certs, oidc_issuer_url)
│   │   └── variables.tf               # Variables du module AKS
│   ├── keyvault/                      # Module Azure Key Vault
│   │   ├── main.tf                    # Ressources Key Vault, règles d'accès et secrets
│   │   ├── outputs.tf                 # Exportations (key_vault_id, vault_uri)
│   │   └── variables.tf               # Variables du module Key Vault
│   └── storage-account/               # Module Azure Storage Account
│       ├── main.tf                    # Compte de stockage, conteneurs Blob (Backups / State)
│       └── variables.tf               # Variables du module Storage Account
├── scripts/
│   ├── bootstrap-backend.sh           # Initialisation du Storage Account pour le backend TF
│   ├── credentials-velero             # Fichier local de crédentiels (exclu par .gitignore)
│   ├── group-creation.sh              # Création des groupes de sécurité Azure AD / Entra ID
│   ├── oidc.sh                        # Configuration Workload Identity & fédération OIDC
│   └── velero-install.sh              # Script CLI pour l'installation autonome de Velero
├── .gitignore                         # Fichiers à ignorer par Git (.tfstate, .terraform, secrets)
├── argocd.tf                          # Installation Helm d'ArgoCD sur le cluster AKS
├── backend.hcl                        # Configuration de paramètres pour le backend azurerm
├── backend.tf                         # Déclaration du backend distant pour le fichier d'état
├── main.tf                            # Instanciation et orchestration des modules Terraform
├── providers.tf                       # Configuration des providers (azurerm, kubernetes, helm)
├── README.md                          # Documentation du dépôt d'infrastructure
├── terraform.tfvars                   # Valeurs des variables locales (exclu par .gitignore)
└── variables.tf                       # Déclaration des variables globales
```

## Prérequis

- Azure CLI authentifié (`az login`) avec les droits nécessaires
- Terraform installé
- `kubectl` installé
- Un dépôt GitHub avec accès aux secrets/variables du repo

## Déploiement

### 1. Créer le backend Terraform

```bash
./scripts/bootstrap-backend.sh
```

Crée le Storage Account + container Blob qui stockera le `tfstate`.

### 2. Créer le groupe Azure AD des employés

```bash
./scripts/group-creation.sh
```

Crée le groupe `mcherfi_employes`, utilisé ensuite pour les droits d'accès au file share SMB.

### 3. Configurer l'authentification OIDC GitHub Actions

```bash
./scripts/oidc.sh
```

Crée une Managed Identity fédérée avec GitHub Actions (branche `main` et pull requests), permettant au pipeline de s'authentifier sur Azure sans secret statique. Récupérer les valeurs affichées (`AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`) et les ajouter aux secrets GitHub du repo.

### 4. Initialiser Terraform

```bash
terraform init --backend-config=backend.hcl
```

### 5. Déployer l'infrastructure

En local :

```bash
terraform plan -out=tfplan
terraform apply tfplan
```

Ou via le pipeline GitHub Actions (`workflow_dispatch`) : choisir l'action `apply` ou `destroy` depuis l'onglet Actions du repo. Le pipeline s'authentifie en OIDC, autorise temporairement l'IP du runner sur le Key Vault (si celui-ci existe déjà), exécute `terraform apply`/`destroy`, puis révoque l'accès IP en fin d'exécution.

Ressources créées principalement :
- **Module AKS** : cluster Kubernetes avec OIDC issuer et workload identity activés
- **Module Key Vault** : clé RSA avec rotation automatique, utilisée pour chiffrer le stockage
- **Module Storage** : Storage Account NFS (données PostgreSQL), Storage Account SMB (données employés), Storage Account de backup Velero chiffré avec la clé du Key Vault, endpoints privés

### 6. Se connecter au cluster

Récupérer les identifiants du cluster (depuis VS Code ou en CLI) :

```bash
az aks get-credentials --resource-group mcherfiRG --name malik-aks-cluster-fr
```

### 7. Installer Velero sur le cluster

```bash
./scripts/velero-install.sh
```

Crée une Managed Identity dédiée à Velero, fédère son identité avec le Service Account Kubernetes `velero`, puis installe Velero avec le plugin Azure, configuré pour utiliser le container Blob `velero` créé par Terraform.