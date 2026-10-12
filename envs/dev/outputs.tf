output "alb_dns_name" {
  description = "Nom de domaine DNS public de l'Application Load Balancer"
  value       = aws_lb.web.dns_name
}

output "target_group_arn" {
  description = "ARN du Target Group associe a l'ALB"
  value       = aws_lb_target_group.web.arn
}

output "vpc_id" {
  description = "ID du VPC cree via le module officiel"
  value       = module.vpc.vpc_id
}

output "public_subnets" {
  description = "Liste des sous-reseaux publics du VPC"
  value       = module.vpc.public_subnets
}

output "asg_name" {
  description = "Nom de l'Auto Scaling Group cree via le module d'equipe"
  value       = module.web_asg.asg_name
}

output "parameter_store_name" {
  description = "Chemin du secret SSM Parameter Store"
  value       = aws_ssm_parameter.db_password.name
}
