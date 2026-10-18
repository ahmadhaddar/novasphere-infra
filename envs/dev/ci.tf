# Configuration OIDC pour GitHub Actions (hors Learner Lab)
# En Learner Lab, la politique SCP interdit la creation de role IAM et OIDC.
# Ce bloc est parametrable via la variable enable_oidc_ci pour basculer facilement sur un compte personnel.

variable "enable_oidc_ci" {
  description = "Activer le fournisseur OIDC et le role CI (uniquement sur compte AWS personnel hors lab)"
  type        = bool
  default     = false
}

resource "aws_iam_openid_connect_provider" "github" {
  count          = var.enable_oidc_ci ? 1 : 0
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

resource "aws_iam_role" "ci" {
  count = var.enable_oidc_ci ? 1 : 0
  name  = "novasphere-ci-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.github[0].arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = { "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com" }
        StringLike   = { "token.actions.githubusercontent.com:sub" = "repo:ahmadhaddar/novasphere-infra:*" }
      }
    }]
  })
}
