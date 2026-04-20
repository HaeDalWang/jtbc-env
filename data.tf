# 리전, 가용 영역, AMI 데이터 소스
data "aws_region" "current" {}

data "aws_availability_zones" "azs" {
  state = "available"
}

# Ubuntu 24.04 LTS (Noble) — Canonical SSM. 23.10+ 루트 볼륨은 ebs-gp3 (ebs-gp2는 <=23.04)
# 참고: https://documentation.ubuntu.com/aws/en/latest/aws-how-to/instances/find-ubuntu-images/
data "aws_ssm_parameter" "ubuntu_24_04_ami" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}
