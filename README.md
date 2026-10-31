# NovaSphere Infrastructure — Déploiement Multi-Environnements en Continu

Ce dépôt héberge le code d'infrastructure comme code (IaC) Terraform pour le projet **NovaSphere**, déployé sur Amazon Web Services (AWS) en deux environnements isolés (`dev` et `prod`), avec intégration et livraison continues via GitHub Actions.

---

## 1. Prérequis

Avant de déployer, assurez-vous de disposer des outils suivants sur votre poste :
- **Terraform** $\ge$ 1.14 (recommandé 1.16+) : `terraform version`
- **AWS CLI** v2 : `aws --version`
- **Git** $\ge$ 2.30 : `git --version`
- **Curl** et **jq** pour les vérifications

---

## 2. Configuration des Accès AWS

Dans le cadre d'un compte **AWS Academy Learner Lab** :
1. Démarrez votre lab depuis le portail AWS Academy.
2. Cliquez sur **AWS Details** > **AWS CLI : Show**.
3. Renseignez ces identifiants dans votre fichier `~/.aws/credentials` (ou `$env:USERPROFILE\.aws\credentials` sous Windows) :

```ini
[default]
aws_access_key_id = ASIA...
aws_secret_access_key = ...
aws_session_token = ...
region = us-east-1
```

Vérifiez l'authentification :
```bash
aws sts get-caller-identity
```

---

## 3. Architecture du Dépôt

```text
novasphere-infra/
├── .github/workflows/
│   ├── terraform-pr.yml      # CI : validation, fmt et plan en commentaire de PR
│   └── terraform-apply.yml   # CD : apply dev automatique, prod protegee, job drift
├── envs/
│   ├── dev/                  # Environnement de developpement
│   └── prod/                 # Environnement de production
├── scripts/
│   ├── start-morning.sh      # Script de reprise de session
│   └── stop-evening.sh       # Destruction rapide des ressources en fin de seance
├── ARCHITECTURE.md           # Schema d'architecture et justifications
├── SECURITE.md               # Cartographie des secrets et rapport Checkov
├── CONTRIBUTING.md           # Conventions de developpement et regles Git
├── CADRAGE.md                # Fiche de cadrage d'equipe (Seance 8)
└── RESTE_A_FAIRE.md          # Suivi d'equipe (Seance 9)
```

---

## 4. Déploiement Pas-à-Pas (De Zéro)

Le socle backend partagé repose sur le bucket S3 mondial `novasphere-tfstate-hbq` avec chiffrement et verrouillage natif (`use_lockfile = true`).

### Étape 4.1 : Déploiement de l'environnement DEV

1. **Se positionner dans le répertoire dev :**
   ```bash
   cd envs/dev
   ```

2. **Définir le mot de passe applicatif en variable d'environnement :**
   *(Ne jamais renseigner de mot de passe en dur dans les fichiers `.tf` ou `tfvars` !)*
   ```bash
   # Linux / macOS / Git Bash :
   export TF_VAR_db_password="<mot-de-passe-dev>"

   # Windows PowerShell :
   $env:TF_VAR_db_password="<mot-de-passe-dev>"
   ```

3. **Initialiser Terraform :**
   ```bash
   terraform init
   ```

4. **Valider la syntaxe et les règles :**
   ```bash
   terraform fmt -check
   terraform validate
   ```

5. **Générer et examiner le plan :**
   ```bash
   terraform plan -out=tfplan
   ```

6. **Appliquer le plan validé :**
   ```bash
   terraform apply tfplan
   ```

---

## 5. Vérification du Déploiement

1. **Récupérer l'URL publique de l'Application Load Balancer :**
   ```bash
   ALB_URL=$(terraform output -raw alb_dns_name)
   echo "URL ALB : http://${ALB_URL}"
   ```

2. **Tester la répartition de charge et la réponse HTTP :**
   Patientez 1 à 2 minutes que le Target Group valide les instances en vert (health check). Puis exécutez :
   ```bash
   for i in {1..4}; do curl -s "http://${ALB_URL}" | grep -o "i-[a-z0-9]*"; done
   ```
   *Résultat attendu :* Les requêtes alternent entre les deux IDs d'instances créées dans les deux zones de disponibilité.

3. **Vérifier l'absence absolue de secret dans le tfstate :**
   ```bash
   terraform state pull | grep -c "$TF_VAR_db_password"
   # Doit retourner 0
   ```

---

## 6. Déploiement de l'environnement PROD

Le déploiement en production suit exactement la même rigueur :
```bash
cd ../prod
export TF_VAR_db_password="<mot-de-passe-prod>"
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

---

## 7. Détection et Test de Dérive (Drift)

Pour simuler une dérive manuelle hors Terraform (ex: ajout d'une règle de Security Group non autorisée) :
```bash
# Modifier une ressource via l'AWS CLI
# Puis verifier la detection par Terraform :
terraform plan -detailed-exitcode
```
- Code `0` : Aucune divergence, infrastructure conforme au code.
- Code `2` : Dérive détectée ! Une modification non tracée est apparue.

---

## 8. Procédure de Destruction Complète

À la fin de chaque séance de travail ou évaluation, pour respecter le quota budgétaire du Learner Lab :

```bash
# 1. Destruction de Dev
cd envs/dev
terraform destroy -auto-approve

# 2. Destruction de Prod
cd ../prod
terraform destroy -auto-approve
```
