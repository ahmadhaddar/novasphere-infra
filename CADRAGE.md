# Fiche de cadrage — Projet fil rouge NovaSphere (Séance 8)

## 1. Membres de l'équipe et rôles
- **Groupe :** MAS_SE2_000_AI - Équipe 1
- **Ahmad HADDAR** : Référent Git & Référent AWS
- **Loan QUELARD** : Membre équipe infrastructure
- **Ewan BERTHOMIEU** : Membre équipe infrastructure

## 2. Contexte métier (5 lignes)
NovaSphere est une entreprise éditrice d'une solution SaaS de supervision d'infrastructure cloud hautement disponible. Afin de soutenir la croissance de ses clients et d'éviter tout incident de production, l'équipe refond l'architecture sur AWS. Le service requiert une haute résilience sans point de défaillance unique, une étanchéité stricte entre le dev et la prod, et une chaîne de livraison automatisée garantissant un déploiement continu sécurisé.

## 3. Ce que servent les instances
Les instances EC2 exécutent Nginx et servent l'API et l'interface d'état NovaSphere sur le port 80. Chaque instance lit au démarrage son secret applicatif chiffré depuis AWS SSM Parameter Store grâce à son profil IAM, sans aucun secret présent dans le script de démarrage ni dans le code. La page web racine `/` affiche le nom de l'environnement, l'identifiant d'instance pour attester du bon fonctionnement de la répartition de charge, et le statut d'extraction du secret.

## 4. Extension choisie
- **Extension bonus :** Tests de module automatisés (`terraform test`) & Administration sans SSH via AWS Systems Manager (SSM Session Manager).
- **Exigences techniques :** 
  - Exécution de tests unitaires et validation d'assertions de sécurité au niveau du module d'équipe dans le cycle CI/CD.
  - Sécurisation absolue des instances EC2 en fermant complètement le port 22 (aucun port SSH ouvert), avec administration interactive via SSM Session Manager reposant sur les autorisations du rôle `LabInstanceProfile`.
  - Zéro composant facturé inutilement (pas de NAT Gateway requise).

## 5. Ce que l'équipe écarte et pourquoi
- **NAT Gateway :** Écartée car facturée à l'heure (~0,05 $/h) et pénalisante pour le budget du Learner Lab. Les instances résident en subnets publics, sécurisées par un Security Group hermétique n'acceptant que les requêtes émanant du Security Group de l'ALB.
- **Workspaces Terraform :** Écartés pour la séparation dev/prod conformément à l'exigence du module. Les répertoires `envs/dev` et `envs/prod` offrent un cloisonnement explicite des droits, des states et des credentials.
- **Secrets dans le tfstate (`sensitive = true`) :** Écarté car insuffisant (le secret reste stocké en clair dans le fichier JSON du state). Remplacé par `value_wo` et variables `ephemeral = true` (Terraform $\ge$ 1.11).

## 6. Compte AWS utilisé pour la démonstration
- **Environnement :** AWS Academy Learner Lab
- **Account ID :** `221242518187`
- **Région autorisée :** `us-east-1`
- **Instance Profile :** `LabInstanceProfile`
- **Bucket S3 du backend :** `novasphere-tfstate-hbq`
