# Module VPC officiel du registre Terraform (Cahier des charges S4)
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.0"

  name = local.name
  cidr = var.vpc_cidr

  azs            = local.azs
  public_subnets = var.public_subnets

  # Aucune NAT Gateway pour eviter la facturation a l'heure dans le Learner Lab
  enable_nat_gateway = false
  single_nat_gateway = false

  # IP publique activee au lancement pour permettre la sortie Internet directe via l'IGW
  map_public_ip_on_launch = true

  tags = {
    Environment = var.environment
  }
}
