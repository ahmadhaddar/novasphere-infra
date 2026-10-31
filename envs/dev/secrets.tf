# Secret applicatif stocke dans AWS Systems Manager Parameter Store
# L'argument value_wo (ecriture seule) garantit qu'aucune valeur de secret ne persiste dans le tfstate
resource "aws_ssm_parameter" "db_password" {
  #checkov:skip=CKV_AWS_337:SecureString chiffre par la cle KMS geree par AWS (aws/ssm), pas de CMK dans le lab
  name             = "/novasphere/${var.environment}/db_password"
  description      = "Mot de passe de base de donnees applicatif (${var.environment})"
  type             = "SecureString"
  value_wo         = var.db_password
  value_wo_version = 1

  tags = {
    Environment = var.environment
  }
}
