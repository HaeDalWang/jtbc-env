# 프라이빗 EC2(HTTP 80) + 퍼블릭 ALB + WAFv2(IP 화이트리스트)

# --- 보안 그룹 ---
resource "aws_security_group" "alb" {
  name_prefix = "${local.iam_prefix}alb${local.name_suffix_01}-sg-"
  description = "ALB inbound TCP ${var.alb_listener_port} from Internet (WAF enforces allowlist)"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "HTTP from Internet; WAF allowlist applies before traffic reaches ALB"
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
    Name = "${local.name_base}-sg-${var.alb_role_name}${local.name_suffix_01}"
  }
}

resource "aws_security_group" "ec2_app" {
  name_prefix = "${local.iam_prefix}${var.ec2_role_name}${local.name_suffix_01}-sg-"
  description = "private EC2 to ALB port ${var.target_port} allow"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "ALB to HTTP"
    from_port       = var.target_port
    to_port         = var.target_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    description     = "SSH from bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
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
    Name = "${local.name_base}-sg-${var.ec2_role_name}${local.name_suffix_01}"
  }
}

# --- EC2 IAM (Session Manager용) ---
resource "aws_iam_role" "ec2_app" {
  name_prefix = "${local.iam_prefix}${var.ec2_role_name}${local.name_suffix_01}-iam-"

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
    Name = "${local.name_base}-iam-${var.ec2_role_name}${local.name_suffix_01}"
  }
}

resource "aws_iam_role_policy_attachment" "ec2_ssm" {
  role       = aws_iam_role.ec2_app.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_app" {
  name_prefix = "${local.iam_prefix}${var.ec2_role_name}${local.name_suffix_01}-prof-"
  role        = aws_iam_role.ec2_app.name
}

# --- EC2 (예: …-was-1, …-was-2) ---
resource "aws_instance" "app" {
  count = var.ec2_instance_count

  ami                    = data.aws_ssm_parameter.ubuntu_24_04_ami.value
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
    Name = format("%s-%s%02d", local.name_base, var.ec2_role_name, count.index + 1)
  }

  lifecycle {
    ignore_changes = [ami]
  }
}

# --- ALB & 타깃 그룹 ---
resource "aws_lb_target_group" "app" {
  name        = local.name_target_group
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
    Name = "${local.name_base}-tg${local.name_suffix_01}"
  }
}

resource "aws_lb_target_group_attachment" "app" {
  count = var.ec2_instance_count

  target_group_arn = aws_lb_target_group.app.arn
  target_id        = aws_instance.app[count.index].id
  port             = var.target_port
}

resource "aws_lb" "app" {
  name               = local.name_alb
  load_balancer_type = "application"
  internal           = false
  security_groups    = [aws_security_group.alb.id]
  subnets            = module.vpc.public_subnets

  tags = {
    Name = local.name_alb
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
  name               = local.name_waf_ipset
  scope              = "REGIONAL"
  ip_address_version = "IPV4"
  addresses          = local.waf_ipv4_normalized

  tags = {
    Name = "${local.name_base}-waf-ipset${local.name_suffix_01}"
  }
}

resource "aws_wafv2_web_acl" "alb" {
  name  = local.name_waf_acl
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
      metric_name                = substr("${local.name_base}-AllowWhitelistIpv4", 0, 128)
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = substr("${local.name_base}-waf-acl", 0, 128)
    sampled_requests_enabled   = true
  }

  tags = {
    Name = "${local.name_base}-waf-acl${local.name_suffix_01}"
  }
}

resource "aws_wafv2_web_acl_association" "alb" {
  resource_arn = aws_lb.app.arn
  web_acl_arn  = aws_wafv2_web_acl.alb.arn
}
