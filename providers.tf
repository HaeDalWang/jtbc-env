# 요구되는 테라폼 제공자 목록
# 버전 기준: 2025년 12월 31일
terraform {
  required_version = ">= 1.13.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.26.0"
    }
    htpasswd = {
      source  = "loafoe/htpasswd"
      version = "~> 1.5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

# AWS 제공자 설정
provider "aws" {
  # jtbc 계정 assume
  # assume_role {
  #   role_arn = "arn:aws:iam::277304862588:role/saltware-terraform-role"
  #   session_name = "terraform"
  # }
  default_tags {
    tags = local.tags
  }
}