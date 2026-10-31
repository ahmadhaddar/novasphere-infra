# Security Group de l'Application Load Balancer (expose sur Internet en HTTP 80)
resource "aws_security_group" "alb" {
  #checkov:skip=CKV_AWS_260:ALB public, le socle impose HTTP 80 ouvert depuis Internet (pas de certificat ACM dans le lab)
  name_prefix = "${local.name}-alb-sg-"
  description = "Security Group public pour l'Application Load Balancer"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "HTTP entrant depuis Internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Sortie limitee au port 80 vers le VPC : l'ALB ne parle qu'aux instances du target group
  egress {
    description = "HTTP sortant vers les instances du VPC uniquement"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${local.name}-alb-sg"
  }
}

# Application Load Balancer
resource "aws_lb" "web" {
  #checkov:skip=CKV_AWS_150:Protection contre la suppression desactivee pour permettre terraform destroy en fin de session (lab)
  #checkov:skip=CKV_AWS_91:Access logs ALB non actives pour eviter un bucket S3 de logs supplementaire dans le lab
  #checkov:skip=CKV2_AWS_20:Pas de redirection HTTPS sans certificat ACM ni domaine dans le lab
  #checkov:skip=CKV2_AWS_28:WAF hors perimetre du socle et facture, non retenu pour le lab
  name                       = "${local.name}-alb"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.alb.id]
  subnets                    = module.vpc.public_subnets
  drop_invalid_header_fields = true

  tags = {
    Name = "${local.name}-alb"
  }
}

# Target Group HTTP pour les instances EC2
resource "aws_lb_target_group" "web" {
  #checkov:skip=CKV_AWS_378:Trafic ALB vers instances en HTTP dans le VPC prive au SG, terminaison TLS hors perimetre du lab
  name_prefix = substr("${var.environment}-tg-", 0, 6)
  port        = 80
  protocol    = "HTTP"
  vpc_id      = module.vpc.vpc_id

  health_check {
    enabled             = true
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${local.name}-tg"
  }
}

# Listener ALB sur le port 80 vers le Target Group
resource "aws_lb_listener" "http" {
  #checkov:skip=CKV_AWS_2:HTTP 80 impose par le socle, pas de certificat ACM ni de domaine dans le lab
  #checkov:skip=CKV_AWS_103:Pas de TLS sans listener HTTPS (voir CKV_AWS_2)
  load_balancer_arn = aws_lb.web.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

# Appel du module d'equipe versionne par tag Git
module "web_asg" {
  #checkov:skip=CKV_TF_1:Le cahier des charges impose un module appele par tag Git (ref=vX.Y.Z), pas par hash de commit
  source = "git::https://github.com/ahmadhaddar/terraform-aws-web-asg.git?ref=v1.1.0"

  name_prefix               = local.name
  vpc_id                    = module.vpc.vpc_id
  subnet_ids                = module.vpc.public_subnets
  alb_security_group_id     = aws_security_group.alb.id
  target_group_arn          = aws_lb_target_group.web.arn
  ami_id                    = data.aws_ami.debian.id
  instance_type             = var.instance_type
  iam_instance_profile_name = "LabInstanceProfile"
  user_data_base64          = base64encode(replace(file("${path.module}/bootstrap.sh"), "ENV_PLACEHOLDER", var.environment))
  min_size                  = var.asg_min_size
  max_size                  = var.asg_max_size
  desired_capacity          = var.asg_desired_capacity

  tags = {
    Environment = var.environment
    Service     = "web"
  }
}
