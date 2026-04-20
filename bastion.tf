# 퍼블릭 서브넷 바스티온 (패턴: {base}-{bastion_role_name}{01})

resource "aws_security_group" "bastion" {
  name_prefix = "${local.iam_prefix}${var.bastion_role_name}${local.name_suffix_01}-sg-"
  description = "Bastion host (optional SSH from bastion_ssh_allowed_cidr_blocks)"
  vpc_id      = module.vpc.vpc_id

  dynamic "ingress" {
    for_each = length(var.bastion_ssh_allowed_cidr_blocks) > 0 ? [1] : []
    content {
      description = "SSH from trusted CIDRs"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = var.bastion_ssh_allowed_cidr_blocks
    }
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
    Name = "${local.name_base}-sg-${var.bastion_role_name}${local.name_suffix_01}"
  }
}

resource "aws_iam_role" "bastion" {
  name_prefix = "${local.iam_prefix}${var.bastion_role_name}${local.name_suffix_01}-iam-"

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
    Name = "${local.name_base}-iam-${var.bastion_role_name}${local.name_suffix_01}"
  }
}

resource "aws_iam_role_policy_attachment" "bastion_ssm" {
  role       = aws_iam_role.bastion.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "bastion" {
  name_prefix = "${local.iam_prefix}${var.bastion_role_name}${local.name_suffix_01}-prof-"
  role        = aws_iam_role.bastion.name
}

resource "aws_instance" "bastion" {
  ami                         = data.aws_ssm_parameter.ubuntu_24_04_ami.value
  instance_type               = var.bastion_instance_type
  subnet_id                   = module.vpc.public_subnets[0]
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  iam_instance_profile        = aws_iam_instance_profile.bastion.name

  key_name = var.bastion_key_name != null ? var.bastion_key_name : var.ec2_key_name

  tags = {
    Name = "${local.name_base}-${var.bastion_role_name}${local.name_suffix_01}"
  }

  lifecycle {
    ignore_changes = [ami]
  }
}
