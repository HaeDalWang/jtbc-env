# 프라이빗 EC2(HTTP 80) + 퍼블릭 ALB + WAFv2(IP 화이트리스트)

# --- 보안 그룹 ---
resource "aws_security_group" "alb" {
  name_prefix = "${local.name_prefix}-alb-"
  description = "ALB 인바운드 (포트 ${var.alb_listener_port})"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "인터넷에서 HTTP (실제 허용은 WAF 화이트리스트)"
    from_port   = var.alb_listener_port
    to_port     = var.alb_listener_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${local.name_prefix}-sg-alb"
  }
}

resource "aws_security_group" "ec2_app" {
  name_prefix = "${local.name_prefix}-ec2-"
  description = "프라이빗 EC2 — ALB에서만 포트 ${var.target_port} 허용"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "ALB에서 HTTP"
    from_port       = var.target_port
    to_port         = var.target_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${local.name_prefix}-sg-ec2-app"
  }
}

# --- EC2 IAM (Session Manager용) ---
resource "aws_iam_role" "ec2_app" {
  name_prefix = "${local.name_prefix}-ec2-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })

  tags = {
    Name = "${local.name_prefix}-iam-ec2-app"
  }
}

resource "aws_iam_role_policy_attachment" "ec2_ssm" {
  role       = aws_iam_role.ec2_app.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_app" {
  name_prefix = "${local.name_prefix}-ec2-"
  role        = aws_iam_role.ec2_app.name
}

# --- EC2 ---
resource "aws_instance" "app" {
  count = var.ec2_instance_count

  ami                    = data.aws_ami.ubuntu_24_04.id
  instance_type          = var.ec2_instance_type
  subnet_id              = module.vpc.private_subnets[count.index % length(module.vpc.private_subnets)]
  vpc_security_group_ids = [aws_security_group.ec2_app.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_app.name

  key_name = var.ec2_key_name

  user_data = <<-EOT
    #!/bin/bash
    set -eux
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y
    apt-get install -y nginx
    systemctl enable nginx
    systemctl start nginx
  EOT

  tags = {
    Name = "${local.name_prefix}-ec2-app-${count.index + 1}"
  }

  lifecycle {
    ignore_changes = [ami]
  }
}

# --- ALB & 타깃 그룹 ---
resource "aws_lb_target_group" "app" {
  name        = local.tg_resource_name
  port        = var.target_port
  protocol    = "HTTP"
  vpc_id      = module.vpc.vpc_id
  target_type = "instance"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = var.health_check_path
    matcher             = "200"
    protocol            = "HTTP"
    port                = "traffic-port"
  }

  tags = {
    Name = "${local.name_prefix}-tg-app"
  }
}

resource "aws_lb_target_group_attachment" "app" {
  count = var.ec2_instance_count

  target_group_arn = aws_lb_target_group.app.arn
  target_id        = aws_instance.app[count.index].id
  port             = var.target_port
}

resource "aws_lb" "app" {
  name               = local.alb_resource_name
  load_balancer_type = "application"
  internal           = false
  security_groups    = [aws_security_group.alb.id]
  subnets            = module.vpc.public_subnets

  tags = {
    Name = "${local.name_prefix}-alb-app"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = var.alb_listener_port
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# --- WAFv2 (Regional) + IP 화이트리스트 ---
resource "aws_wafv2_ip_set" "alb_allowlist" {
  name               = "${local.name_prefix}-alb-allow-ipv4"
  scope              = "REGIONAL"
  ip_address_version = "IPV4"
  addresses          = var.waf_allowed_ipv4_cidr

  tags = {
    Name = "${local.name_prefix}-waf-ipset-allow"
  }
}

resource "aws_wafv2_web_acl" "alb" {
  name  = "${local.name_prefix}-alb-waf"
  scope = "REGIONAL"

  default_action {
    block {}
  }

  rule {
    name     = "allow-whitelist-ipv4"
    priority = 1

    action {
      allow {}
    }

    statement {
      ip_set_reference_statement {
        arn = aws_wafv2_ip_set.alb_allowlist.arn
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.name_prefix}-AllowWhitelistIpv4"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${local.name_prefix}-waf-acl"
    sampled_requests_enabled   = true
  }

  tags = {
    Name = "${local.name_prefix}-waf-acl-alb"
  }
}

resource "aws_wafv2_web_acl_association" "alb" {
  resource_arn = aws_lb.app.arn
  web_acl_arn  = aws_wafv2_web_acl.alb.arn
}
