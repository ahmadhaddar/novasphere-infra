# Suivi d'équipe — Séance 9 & Phase d'alternance

## État au checkpoint de fin de séance 9 :
- [x] dev déployé par la CI, l'ALB répond sur le port 80
- [x] secret stocké dans Parameter Store, dépôt propre au `git grep`
- [x] prod : environnement GitHub protégé configuré, premier plan lu

## Reste à faire pendant l'alternance (3 items nominatifs) :
1. **Tests unitaires automatisés et assertions de sécurité (`terraform test`)**  
   - *Qui :* Ewan BERTHOMIEU  
   - *Quand :* 24/10/2026 — *Statut :* Terminé (tests dans `terraform-aws-web-asg`, tag `v1.1.0`)

2. **Scan Checkov complet et documentation des choix dans SECURITE.md**  
   - *Qui :* Loan QUELARD  
   - *Quand :* 26/10/2026 — *Statut :* Terminé. Complété le 31/10/2026 par Ahmad HADDAR : annotations `checkov:skip` replacées dans les blocs (elles étaient ignorées), SECURITE.md réaligné sur le scan réel

3. **Validation de la chaîne CI/CD (apply dev + approbation prod) et répétition démo live**  
   - *Qui :* Ahmad HADDAR  
   - *Statut :* Chaîne CI validée le 31/10/2026 (prévue le 28/10) : premier déploiement complet par la CI, dev au merge et prod après approbation (PR #3 et #4). Répétition de la démo : prévue avant la soutenance

## État vérifié au gel (31/10/2026)
- [x] dev et prod déployés par la CI, chaque ALB répond avec deux instances et le secret lu depuis Parameter Store
- [x] aucun mot de passe dans le dépôt (`git grep`) ni dans les tfstate dev et prod (0 occurrence)
- [x] prod protégée : l'environnement GitHub `prod` exige une approbation avant l'apply

---

## Date de gel (tag) :
Tag `rendu-final` posé avant le **samedi 31/10/2026 à 23h59**.

**Signatures des membres de l'équipe :**
- Ahmad HADDAR : *(Signé)*
- Ewan BERTHOMIEU : *(Signé)*
- Loan QUELARD : *(Signé)*
