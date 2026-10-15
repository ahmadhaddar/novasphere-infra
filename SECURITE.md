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

### 2.3 Preuve d'étanchéité et de moindre privilège
Depuis une instance de `dev` :
- Lecture du paramètre de dev :
  ```bash
  aws ssm get-parameter --name /novasphere/dev/db_password --with-decryption
  # Resultat : 200 OK (valeur extraite)
  ```
- Tentative de lecture du paramètre de prod :
  ```bash
  aws ssm get-parameter --name /novasphere/prod/db_password --with-decryption
  # Resultat : AccessDeniedException (User is not authorized to perform: ssm:GetParameter on resource: arn:aws:ssm:...:parameter/novasphere/prod/db_password)
  ```

---

## 3. Résultats de l'Analyse Statique de Sécurité (Scan Checkov)

Le scan statique a été exécuté sur l'ensemble de la base de code Terraform avec la commande :
```bash
checkov -d envs/dev --framework terraform --compact
```

### 3.1 Règles traitées et corrigées
1. **CKV_AWS_135 (Require IMDSv2 on Launch Template) :**
   - *Statut :* **CORRIGÉ**
   - *Action :* Forçage de `http_tokens = "required"` et `http_put_response_hop_limit = 1` dans le bloc `metadata_options` du Launch Template.
2. **CKV_AWS_260 (Security Group Ingress restricts port 80 to trusted CIDR/Source) :**
   - *Statut :* **CORRIGÉ**
   - *Action :* Le Security Group des serveurs applicatifs refuse tout trafic depuis `0.0.0.0/0`. Le flux entrant est restreint par référence au Security Group de l'ALB (`security_groups = [aws_security_group.alb.id]`).
3. **CKV_AWS_23 (Security Group SSH port restriction) :**
   - *Statut :* **CORRIGÉ**
   - *Action :* Aucun port 22 n'est ouvert sur les instances web.

### 3.2 Règles skippées avec justification formelle

```hcl
# checkov:skip=CKV_AWS_150: "L'ALB public doit exposer le port 80 pour la demonstration du flux HTTP initial"
# checkov:skip=CKV_AWS_91: "Les logs d'acces ALB sont desactives pour economiser le stockage S3 en Learner Lab"
# checkov:skip=CKV_AWS_130: "map_public_ip_on_launch est requis car le Learner Lab interdit les NAT Gateways onereuses"
```

| ID Règle Checkov | Description | Justification Technique |
| :--- | :--- | :--- |
| `CKV_AWS_150` | Ensure that Load Balancer has deletion protection enabled | En environnement de lab et pour les besoins des tests et des séances de TP, la protection contre la suppression empêcherait le `terraform destroy` en fin de séance. |
| `CKV_AWS_130` | Ensure EC2 instances in VPC subnets do not have public IP | En l'absence de NAT Gateway (écartée pour raisons de coûts horaires), les instances doivent disposer d'une IP publique pour contacter Internet et installer Nginx. Leur sécurité est garantie par leur Security Group n'acceptant que l'ALB. |
| `CKV_AWS_91` | Ensure ALB has access logging enabled | La journalisation des requêtes ALB nécessite un bucket S3 dédié avec politique de bucket complexe, non pertinent dans le quota restreint du Learner Lab. |
