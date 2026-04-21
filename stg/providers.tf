terraform {
  required_version = ">= 1.13.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.26.0"
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

provider "aws" {
  assume_role {
    role_arn     = "arn:aws:iam::277304862588:role/SaltwareTerraformAssumeRole"
    session_name = "terraform"
  }
  default_tags {
    tags = local.tags
  }
}
