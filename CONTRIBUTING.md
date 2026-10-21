# Conventions d'équipe — novasphere-infra

## Membres de l'équipe (MAS_SE2_000_AI)
- **Ahmad HADDAR** (`ahmadhaddar`) — Référent Git & Référent AWS
- **Ewan BERTHOMIEU** (`ewan-berthomieu`) — Infrastructure Réseau, ASG & CI/CD
- **Loan QUELARD** (`loanquelard-jpg`) — Multi-environnements, Secrets SSM & Sécurité

---

## Règles de collaboration
1. **Une branche par changement** (`feat/...`, `fix/...`, `docs/...`), jamais de commit direct sur `main`.
2. **Revue obligatoire** : Toute modification passe par une Pull Request relue et approuvée par un autre membre avant merge.
3. **Plan Terraform** : Le plan Terraform se lit intégralement avant tout `apply`.
4. **Tags Git** : Un tag par séance (`v5.<séance>.0`) et le tag final `rendu-final`.
5. **`.gitignore` non négociable, jamais modifié à la baisse** : `*.tfstate`, `*.tfvars`, `*.pem`, `.env`, inventaires générés ne sont jamais commités.
6. **Backend S3 distant partagé** : State partagé uniquement sur le bucket S3 d'équipe (`novasphere-tfstate-hbq`), jamais de state local.
7. **Verrouillage natif S3** : `use_lockfile = true`. `dynamodb_table` est déprécié par HashiCorp : on le reconnaît, on ne l'utilise pas.
8. **Gestion des verrous** : Jamais de `terraform force-unlock` sans avoir vérifié avec l'équipe que personne n'a d'opération en cours.
9. **Hygiène absolue des secrets** : Zéro secret en clair (ni dans le code, ni dans le tfstate, ni dans `user_data`, ni dans les logs). Parameter Store (`value_wo`) est la seule source autorisée.
10. **Fin de journée / séance** : `terraform destroy` systématique avant de quitter la séance pour ne jamais consommer de crédits inutiles sur l'ALB et l'ASG.
