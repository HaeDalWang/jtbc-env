module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.5.1"

  name = local.name_vpc
  cidr = var.vpc_cidr

  azs              = ["ap-northeast-2a", "ap-northeast-2c"]
  public_subnets   = var.public_subnet_cidr
  private_subnets  = var.private_subnet_cidr
  database_subnets = var.db_subnet_cidr

  # DB 서브넷 그룹 자동 생성
  create_database_subnet_group       = true
  database_subnet_group_name         = "${local.name_base}-rds-subgrp"
  create_database_subnet_route_table = true

  default_security_group_egress = [
    {
      cidr_blocks      = "0.0.0.0/0"
      ipv6_cidr_blocks = "::/0"
    }
  ]

  enable_nat_gateway = true
  single_nat_gateway = true
  # one_nat_gateway_per_az = true

  public_subnet_tags = {
    "public" = "true"
  }

  private_subnet_tags = {
    "private" = "true"
  }

  database_subnet_tags = {
    "db" = "true"
  }
}

# S3 Gateway 엔드포인트
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${data.aws_region.current.id}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = concat(module.vpc.private_route_table_ids, module.vpc.public_route_table_ids)

  tags = {
    Name = local.name_s3_endpoint
  }
}
