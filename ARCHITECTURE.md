# Architecture de l'Infrastructure NovaSphere

Ce document décrit l'architecture déployée sur Amazon Web Services (AWS) pour l'application SaaS NovaSphere, les choix de conception retenus, les alternatives écartées ainsi que l'extension technique choisie.

---

## 1. Schéma d'Architecture Cible

```text
                                  INTERNET
                                      │
                                      ▼
             [ AWS Route 53 / DNS externe ou DNS public ALB ]
                                      │
                                      ▼ [HTTP : 80]
                  ┌────────────────────────────────────────┐
                  │    Application Load Balancer (ALB)     │
                  │  (public_subnets: us-east-1a, 1b)      │
                  │  Security Group ALB (Ingress: 0.0.0.0/0:80)
                  └───────────────────┬────────────────────┘
                                      │ Health Check HTTP sur /
                                      ▼ Forward (Port 80)
                  ┌────────────────────────────────────────┐
                  │          ALB Target Group (HTTP)       │
                  └───────────────────┬────────────────────┘
                                      │
         ┌────────────────────────────┴───────────────────────────┐
         ▼                                                        ▼
┌─────────────────────────────────┐      ┌─────────────────────────────────┐
│ Zone de Disponibilité us-east-1a│      │ Zone de Disponibilité us-east-1b│
│                                 │      │                                 │
│ [Subnet Public A - 10.0.1.0/24] │      │ [Subnet Public B - 10.0.2.0/24] │
│                                 │      │                                 │
│   ┌─────────────────────────┐   │      │   ┌─────────────────────────┐   │
│   │   Instance EC2 (Web A)  │   │      │   │   Instance EC2 (Web B)  │   │
│   │                         │   │      │   │                         │   │
│   │ SG Web : Ingress 80     │   │      │   │ SG Web : Ingress 80     │   │
│   │ depuis SG ALB UNIQUEMENT│   │      │   │ depuis SG ALB UNIQUEMENT│   │
│   │ AUCUN port SSH ouvert   │   │      │   │ AUCUN port SSH ouvert   │   │
│   │ IMDSv2 Token requis     │   │      │   │ IMDSv2 Token requis     │   │
│   │ LabInstanceProfile (IAM)│   │      │   │ LabInstanceProfile (IAM)│   │
│   └────────────┬────────────┘   │      │   └────────────┬────────────┘   │
└────────────────┼────────────────┘      └────────────────┼────────────────┘
                 │                                        │
                 └──────────────────┬─────────────────────┘
                                    │ Lecture du secret au boot (ssm:GetParameter)
                                    ▼
       ┌─────────────────────────────────────────────────────────────┐
       │             AWS Systems Manager Parameter Store             │
       │    Chemin cloisonne : /novasphere/{env}/db_password         │
       │    Type : SecureString (chiffrement KMS AWS)                │
       │    Ecrit en ecriture seule (value_wo) par Terraform         │
       └─────────────────────────────────────────────────────────────┘
```

---

## 2. Décisions d'Architecture Validées

1. **Isolation stricte Dev et Prod par Répertoires (`envs/dev` et `envs/prod`) :**
   - Chaque environnement dispose de son propre répertoire, de son propre fichier de backend et de sa propre clé dans le bucket S3 (`novasphere/dev/terraform.tfstate` et `novasphere/prod/terraform.tfstate`).
   - L'intégrité et la parité du code sont garanties : le code HCL des deux répertoires est strictement identique, seules les valeurs des variables et la clé de state diffèrent.

2. **Backend S3 d'équipe avec Verrouillage Natif :**
   - Stockage sur le bucket mondial unique `novasphere-tfstate-hbq` avec versionnement actif et chiffrement au repos.
   - Verrouillage natif moderne `use_lockfile = true` (Terraform $\ge$ 1.11) reposant sur les requêtes conditionnelles S3 (`HTTP 412 Precondition Failed` en cas d'accès concurrent), évitant la dépendance dépréciée à une table DynamoDB.

3. **Module Réutilisable Versionné (`terraform-aws-web-asg`) :**
   - Externalisé dans son propre dépôt Git et appelé via des tags de version immuables (`ref=v1.1.0`).
   - Encapsule le Launch Template, le Security Group d'instance (`create_before_destroy = true`) et l'Auto Scaling Group.

4. **Résilience et Tolérance aux Pannes :**
   - Répartition sur 2 zones de disponibilité (`us-east-1a` et `us-east-1b`).
   - Auto Scaling Group configuré avec `health_check_type = "ELB"`, `min_size = 2`, `max_size = 4`. Si une instance devient défaillante, l'ASG la remplace automatiquement sans coupure.

5. **Sécurité et Hygiène des Secrets :**
   - Stockage dans AWS SSM Parameter Store en `SecureString`.
   - Écriture Terraform via `value_wo` et variable `ephemeral = true` : le secret n'est jamais mémorisé dans le `tfstate` ni affiché dans les logs du plan.
   - Lecture au boot via le rôle IAM EC2 au moindre privilège.
   - Protection IMDSv2 obligatoire (`http_tokens = "required"`, `http_put_response_hop_limit = 1`) pour bloquer toute fuite de token de métadonnées (attaques SSRF).

---

## 3. Alternatives Écartées et Justifications

| Solution Écartée | Raison du Rejet | Solution Retenue |
| :--- | :--- | :--- |
| **Workspaces Terraform** | Rejetés par le cahier des charges : workspace courant invisible dans le terminal, risque d'erreur critique de destruction croisée (`terraform destroy`), partage de bucket et de credentials empêchant l'isolation des accès. | Répertoires distincts `envs/dev` et `envs/prod`. |
| **NAT Gateway** | Coût prohibitif en environnement d'apprentissage (~0,05 $/h + trafic par Gateway), consommation excessive des crédits Learner Lab. | Instances en subnets publics protégées par des Security Groups hermétiques (seul l'ALB est autorisé en entrée). |
| **`sensitive = true` pour les secrets** | Masque seulement la valeur dans la sortie console du terminal mais écrit le secret **en clair dans le fichier `terraform.tfstate`**. | Arguments en écriture seule `value_wo` et `ephemeral = true` vers Parameter Store. |
| **Accès SSH direct (Port 22)** | Risque de compromission, gestion lourde de clés privées, interdit par les règles de sécurité du cours. | Port 22 totalement fermé ; administration à distance via SSM Session Manager. |
| **DynamoDB pour le verrouillage** | Méthode historique déclarée officiellement dépréciée par HashiCorp depuis Terraform 1.11. | Verrouillage natif S3 (`use_lockfile = true`). |

---

## 4. Extension Choisie : Tests de Module & Administration SSM

L'équipe a implémenté une double valorisation pour le bonus de 2 points :
1. **Tests unitaires de module (`terraform test`) :** Définis dans `tests/unit_test.tftest.hcl` au sein du module `terraform-aws-web-asg`. Ils valident automatiquement avant déploiement que les contraintes d'architecture (haute disponibilité $\ge 2$, `health_check_type = "ELB"`, et exigence IMDSv2) sont strictement respectées.
2. **Administration sans SSH (SSM Session Manager) :** L'instance profile IAM permet d'ouvrir une session interactive shell sécurisée et auditée via la commande `aws ssm start-session --target <instance-id>`, sans aucune ouverture de port réseau.
