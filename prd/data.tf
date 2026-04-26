data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

data "aws_availability_zones" "azs" {
  state = "available"
}

# Ubuntu 24.04 LTS (Noble) — Canonical SSM
data "aws_ssm_parameter" "ubuntu_24_04_ami" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}
