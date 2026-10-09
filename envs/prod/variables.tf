variable "aws_region" {
  description = "Region AWS pour le deploiement (us-east-1 impose en Learner Lab)"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Nom de l'environnement (dev ou prod)"
  type        = string

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "L'environnement doit etre strictement 'dev' ou 'prod'."
  }
}

variable "owner" {
  description = "Trigramme d'equipe"
  type        = string
  default     = "hbq"
}

variable "vpc_cidr" {
  description = "Plage CIDR pour le VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnets" {
  description = "Liste des plages CIDR des subnets publics (au moins 2 AZ requises)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "instance_type" {
  description = "Type d'instance EC2 pour les serveurs web"
  type        = string
  default     = "t3.micro"
}

variable "asg_min_size" {
  description = "Nombre minimal d'instances gerees par l'ASG"
  type        = number
  default     = 2
}

variable "asg_max_size" {
  description = "Nombre maximal d'instances gerees par l'ASG"
  type        = number
  default     = 4
}

variable "asg_desired_capacity" {
  description = "Capacite desiree pour l'ASG"
  type        = number
  default     = 2
}

variable "db_password" {
  description = "Secret applicatif passe a Parameter Store en ecriture seule via TF_VAR_db_password"
  type        = string
  ephemeral   = true
}
