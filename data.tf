# 리전, 가용 영역, AMI 데이터 소스
data "aws_region" "current" {}

data "aws_availability_zones" "azs" {
  state = "available"
}

# Canonical Ubuntu 24.04 LTS (Noble), amd64, hvm-ssd
data "aws_ami" "ubuntu_24_04" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}
