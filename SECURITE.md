# Registre et Rapport de Sécurité — NovaSphere

Ce document recense la stratégie de sécurité de l'infrastructure NovaSphere, la cartographie des secrets, la politique IAM idéale au moindre privilège, et les résultats détaillés de l'analyse statique de sécurité (Checkov).

---

## 1. Cartographie et Cycle de Vie des Secrets

### 1.1 Constat initial et preuves de fuites éliminées (Séance 5)
Avant la mise en conformité, le mot de passe de base de données fuyait aux quatre emplacements critiques d'une chaîne cloud :
1. **Dans le code source :** Présence d'une valeur par défaut (`default = "..."`) détectable instantanément avec `git grep`.
2. **Dans le state Terraform :** Malgré l'attribut `sensitive = true`, le secret apparaissait en clair dans le fichier JSON du state S3 (`terraform state pull | grep -c "mot_de_passe"` retournait `1`).
3. **Dans le user_data EC2 :** Le secret était passé en clair dans le script de démarrage, lisible par quiconque dispose des droits `ec2:DescribeInstanceAttribute`.
4. **Dans l'historique et les logs CI :** Toute sortie d'exécution sans masquage exposait la valeur.

### 1.2 Solution implémentée : Écriture seule sans mémorisation
Depuis Terraform 1.11, la gestion des secrets repose sur le mécanisme d'**écriture seule** (`write-only`) :
```hcl
variable "db_password" {
  description = "Mot de passe applicatif injecte via variable d'environnement"
  type        = string
  ephemeral   = true
}

resource "aws_ssm_parameter" "db_password" {
  name             = "/novasphere/${var.environment}/db_password"
  type             = "SecureString"
  value_wo         = var.db_password
  value_wo_version = 1
}
```

- **`ephemeral = true` :** Interdit formellement à Terraform de stocker la variable dans le plan ou le state.
- **`value_wo` :** Transmet directement le secret à l'API AWS Parameter Store sans l'enregistrer dans le `tfstate`.
- **Rôle de `value_wo_version` :** Étant donné que Terraform n'a pas accès à la valeur du secret dans le state pour détecter un changement de mot de passe, l'argument `value_wo_version` sert de repère de versionnement : incrémenter cet entier force Terraform à réécrire la nouvelle valeur du secret dans Parameter Store lors d'une rotation.

**Vérification de non-persistance :**
```bash
terraform state pull | grep -c "<valeur_du_secret>"
# Retourne 0 : le secret est strictement absent du tfstate.
```

---

## 2. Politique IAM au Moindre Privilège

### 2.1 Contexte Learner Lab vs Production Réelle
Dans l'environnement de formation **AWS Academy Learner Lab**, la création de nouveaux rôles IAM EC2 est bloquée par les Service Control Policies (SCP). Les instances utilisent donc le profil prédéfini `LabInstanceProfile`.

### 2.2 Politique IAM idéale de Production (Documentée pour conformité)
En environnement de production hors Learner Lab, l'instance EC2 doit être restreinte au strict chemin de son propre environnement :

#### Rôle AssumeRole EC2
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

#### Politique de moindre privilège pour l'environnement Dev
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowReadDevParametersOnly",
      "Effect": "Allow",
      "Action": [
        "ssm:GetParameter",
        "ssm:GetParameters"
      ],
      "Resource": "arn:aws:ssm:us-east-1:221242518187:parameter/novasphere/dev/*"
    }
  ]
}
```

### 2.3 Contrainte du Learner Lab : pas de rôle par environnement
La création d'un rôle IAM est refusée dans le Learner Lab. Test réalisé le 31/10/2026 depuis CloudShell :
```text
$ aws iam create-role --role-name test-novasphere --assume-role-policy-document '{...}'
AccessDenied: User: arn:aws:sts::221242518187:assumed-role/voclabs/... is not authorized
to perform: iam:CreateRole ... because no identity-based policy allows the iam:CreateRole action
```
Conséquences assumées :
- Les instances de dev et de prod utilisent toutes les deux `LabInstanceProfile`. **L'étanchéité dev/prod au niveau IAM n'est donc pas garantie dans le lab** : une instance de dev peut techniquement lire `/novasphere/prod/*`.
- La politique de la section 2.2 est la cible hors lab : un rôle et un profil d'instance par environnement, chacun limité à `/novasphere/<env>/*`.

### 2.4 Authentification de la CI
Même contrainte pour l'OIDC : sans `iam:CreateRole`, le rôle assumé par GitHub Actions ne peut pas être créé. Aucun fournisseur OIDC n'existe dans le compte du lab (`aws iam list-open-id-connect-providers` vide).
- **Dans le lab** : credentials de session du Learner Lab stockés dans les secrets GitHub (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`). Ils expirent avec la session du lab et sont renouvelés avant chaque utilisation (voir README).
- **Hors lab** : `envs/<env>/ci.tf` contient déjà le fournisseur OIDC et le rôle `novasphere-ci-<env>` restreint au dépôt, activables avec `enable_oidc_ci = true`. Plus aucune clé stockée, credentials temporaires d'une heure par exécution.

---

## 3. Analyse statique (Checkov)

Commande, à la racine du dépôt :
```bash
checkov -d envs --framework terraform --compact
```
Résultat au 31/10/2026 (Checkov 3.4.0) : **32 passed, 0 failed, 24 skipped** (12 par environnement).

Avant correction, les annotations `checkov:skip` étaient placées au-dessus des ressources, donc ignorées par Checkov (28 échecs, 0 skip). Elles sont maintenant à l'intérieur de chaque bloc, comme l'exige la syntaxe.

### 3.1 Corrigé dans le code
- **CKV_AWS_131** : l'ALB rejette les en-têtes HTTP invalides (`drop_invalid_header_fields = true`).
- **CKV_AWS_382** : la sortie du Security Group de l'ALB est limitée au port 80 vers le CIDR du VPC (avant : tout protocole vers 0.0.0.0/0).
- **IMDSv2** : `http_tokens = "required"` et `http_put_response_hop_limit = 1` sur le Launch Template (module).
- **SSH** : aucun port 22 ouvert. Le Security Group des instances n'accepte que le port 80 depuis le Security Group de l'ALB.

### 3.2 Ignoré avec justification
- **CKV_AWS_260, CKV_AWS_2, CKV_AWS_103, CKV2_AWS_20, CKV_AWS_378** : HTTP en clair. Le socle impose un ALB public sur le port 80 ; sans domaine ni certificat ACM dans le lab, pas de HTTPS.
- **CKV_AWS_150** : pas de protection contre la suppression de l'ALB, pour pouvoir faire `terraform destroy` à chaque fin de session.
- **CKV_AWS_91** : pas de logs d'accès ALB, pour éviter un bucket S3 de logs supplémentaire dans le budget du lab.
- **CKV2_AWS_28** : pas de WAF, hors périmètre du socle et facturé.
- **CKV_AWS_337** : le SecureString est chiffré par la clé KMS gérée par AWS (`aws/ssm`), pas de clé KMS client dans le lab.
- **CKV_TF_1** : modules épinglés par version (`~> 6.0` pour le VPC du registre, `ref=v1.1.0` pour le module d'équipe) et non par hash de commit, comme le demande le cahier des charges.
- **CKV_AWS_394** : seules les deux premières zones de disponibilité sont retenues via `slice()`, l'ajout d'une zone par AWS ne change pas l'infrastructure.

---

## 4. Hygiène Git

- Aucun mot de passe dans le code, le README ou les workflows. Vérification : `git grep -niE "password\s*=\s*\"[^$<]"` ne renvoie rien.
- Les secrets de la CI vivent uniquement dans les secrets GitHub (`TF_VAR_DB_PASSWORD`, `TF_VAR_DB_PASSWORD_PROD`).
- Des mots de passe d'exemple ont figuré dans le README et les workflows avant le 31/10/2026. Ils n'ont jamais été utilisés comme valeur réelle : au moment de la correction, aucun paramètre `/novasphere/*/db_password` n'existait dans Parameter Store. Les mots de passe actuels sont neufs.
- `.gitignore` exclut `*.tfstate*`, `*.tfvars` (sauf les exemples), `*.pem`, `.env` et `.terraform/`.
