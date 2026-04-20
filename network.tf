# VPC
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.5.1" # 최신화 2025년 12월 31일

  name = local.name_prefix
  cidr = var.vpc_cidr

  azs             = data.aws_availability_zones.azs.names
  public_subnets  = var.public_subnet_cidr
  private_subnets = var.private_subnet_cidr

  default_security_group_egress = [
    {
      cidr_blocks      = "0.0.0.0/0"
      ipv6_cidr_blocks = "::/0"
    }
  ]

  enable_nat_gateway = true
  single_nat_gateway = true

  public_subnet_tags = {
    "public" = "true"
  }

  private_subnet_tags = {
    "private" = "true"
  }
}

# S3는 Gateway 엔드포인트 — subnet_ids 불가, 라우트 테이블에 프리픽스 목록 라우트가 붙음
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${data.aws_region.current.id}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = concat(module.vpc.private_route_table_ids, module.vpc.public_route_table_ids)

  tags = {
    Name    = "${local.name_prefix}-s3-endpoint"
    project = local.project
  }
}