# Security Group de l'Application Load Balancer (Expose sur Internet port 80)
# checkov:skip=CKV_AWS_260: "Le Security Group de l'ALB public doit accepter le trafic HTTP entrant depuis Internet"
resource "aws_security_group" "alb" {
  name_prefix = "${local.name}-alb-sg-"
  description = "Security Group public pour l'Application Load Balancer"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "Allow inbound HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic to target group instances"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${local.name}-alb-sg"
  }
}

# Application Load Balancer
# checkov:skip=CKV_AWS_150: "Protection contre la suppression desactivee pour permettre terraform destroy en fin de TP"
# checkov:skip=CKV_AWS_91: "Access logs ALB non actives pour eviter le surcout S3 dans le Learner Lab"
resource "aws_lb" "web" {
  name               = "${local.name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = module.vpc.public_subnets

  tags = {
    Name = "${local.name}-alb"
  }
}

# Target Group HTTP pour les instances EC2
resource "aws_lb_target_group" "web" {
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

# Listener ALB sur le port 80 forwardant le trafic vers le Target Group
# checkov:skip=CKV_AWS_2: "Le listener HTTP 80 est requis par le cahier des charges socle pour la demonstration"
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.web.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

# Appel du module d'equipe versionne par tag Git (Cahier des charges S2/S4/S7)
module "web_asg" {
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
