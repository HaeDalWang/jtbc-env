# 프라이빗 EC2(WAS) + 퍼블릭 ALB + WAFv2

# --- 보안 그룹 ---
resource "aws_security_group" "alb" {
  name        = local.name_sg_alb
  description = "ALB inbound TCP ${var.alb_listener_port} from Internet (WAF enforces allowlist)"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "HTTP from whitelisted IPs"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = local.waf_ipv4_normalized
  }

  ingress {
    description = "HTTPS from whitelisted IPs"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = local.waf_ipv4_normalized
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = false
  }

  tags = {
    Name = local.name_sg_alb
  }
}

resource "aws_security_group" "ec2_app" {
  name        = local.name_sg_was
  description = "Private WAS: ALB port ${var.target_port} + Bastion SSH"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "ALB to WAS"
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

  ingress {
    description     = "SSH 2211 from bastion"
    from_port       = 2211
    to_port         = 2211
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
    Name = local.name_sg_was
  }
}

# --- EC2 IAM (SSM + CloudWatch Agent) ---
resource "aws_iam_role" "ec2_app" {
  name = local.name_iam_was

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = {
    Name = local.name_iam_was
  }
}

resource "aws_iam_role_policy_attachment" "ec2_ssm" {
  role       = aws_iam_role.ec2_app.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "ec2_app_cw_agent" {
  role       = aws_iam_role.ec2_app.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# WAS EC2 인라인 정책 — SSM/S3/CloudFront 권한 통합
resource "aws_iam_role_policy" "ec2_app" {
  name = "${local.name_iam_was}-policy"
  role = aws_iam_role.ec2_app.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "SSMParameterStore"
        Effect   = "Allow"
        Action   = ["ssm:GetParameter", "ssm:GetParameters", "ssm:GetParametersByPath"]
        Resource = "arn:aws:ssm:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:parameter/metaj-cms/*"
      },
      {
        Sid    = "S3ObjectAccess"
        Effect = "Allow"
        Action = ["s3:PutObject", "s3:GetObject", "s3:DeleteObject"]
        Resource = [
          "${aws_s3_bucket.buckets["svc"].arn}/*",
          "${aws_s3_bucket.buckets["adm"].arn}/*",
        ]
      },
      {
        Sid    = "S3BucketList"
        Effect = "Allow"
        Action = ["s3:ListBucket"]
        Resource = [
          aws_s3_bucket.buckets["svc"].arn,
          aws_s3_bucket.buckets["adm"].arn,
        ]
      },
      {
        Sid      = "CloudFrontInvalidation"
        Effect   = "Allow"
        Action   = ["cloudfront:CreateInvalidation", "cloudfront:GetInvalidation"]
        Resource = aws_cloudfront_distribution.svc.arn
      }
    ]
  })
}

resource "aws_iam_instance_profile" "ec2_app" {
  name = "${local.name_iam_was}-profile"
  role = aws_iam_role.ec2_app.name
}

# --- WAS EC2 (엑셀: prd-news-metaj-was-01, was-02) ---
resource "aws_instance" "app" {
  count = var.ec2_instance_count

  ami                    = data.aws_ssm_parameter.ubuntu_24_04_ami.value
  instance_type          = var.ec2_instance_type
  subnet_id              = module.vpc.private_subnets[count.index % length(module.vpc.private_subnets)]
  vpc_security_group_ids = [aws_security_group.ec2_app.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_app.name
  key_name               = var.ec2_key_name

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.ec2_ebs_size_gb
    delete_on_termination = true
  }

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
    # 엑셀 기준: stg-news-metaj-was-01 (하이픈 후 번호)
    Name = format("%s-%s-%02d", local.name_base, var.ec2_role_name, count.index + 1)
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
    Name = local.name_target_group
  }
}

resource "aws_lb_target_group_attachment" "app" {
  count            = var.ec2_instance_count
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

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.app.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = data.aws_acm_certificate.alb.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# HTTP → HTTPS 리다이렉트
resource "aws_lb_listener" "http_redirect" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# --- WAFv2 (Regional) ---
resource "aws_wafv2_ip_set" "alb_allowlist" {
  name               = local.name_waf_ipset
  scope              = "REGIONAL"
  ip_address_version = "IPV4"
  addresses          = local.waf_ipv4_normalized

  tags = {
    Name = local.name_waf_ipset
  }
}

resource "aws_wafv2_web_acl" "alb" {
  name  = local.name_waf_acl
  scope = "REGIONAL"

  default_action {
    block {}
  }

  # Priority 1: IP 화이트리스트
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

  # Priority 2: AWS 공통 관리형 룰셋
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = substr("${local.name_base}-CommonRuleSet", 0, 128)
      sampled_requests_enabled   = true
    }
  }

  # Priority 3: 알려진 악성 입력 차단
  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 3

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = substr("${local.name_base}-KnownBadInputs", 0, 128)
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = substr("${local.name_base}-waf-acl", 0, 128)
    sampled_requests_enabled   = true
  }

  tags = {
    Name = local.name_waf_acl
  }
}

resource "aws_wafv2_web_acl_association" "alb" {
  resource_arn = aws_lb.app.arn
  web_acl_arn  = aws_wafv2_web_acl.alb.arn
}
