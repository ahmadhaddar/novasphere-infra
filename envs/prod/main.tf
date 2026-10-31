# Donnees dynamiques AWS
data "aws_availability_zones" "available" {
  #checkov:skip=CKV_AWS_394:On ne retient que les 2 premieres zones via slice(), l'ajout d'une zone par AWS ne change rien
  state = "available"
}

data "aws_ami" "debian" {
  most_recent = true
  owners      = ["136693071363"] # Debian Official

  filter {
    name   = "name"
    values = ["debian-12-amd64-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

locals {
  name = "novasphere-${var.environment}"
  azs  = slice(data.aws_availability_zones.available.names, 0, 2)
}
