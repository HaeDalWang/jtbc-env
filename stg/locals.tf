# 네이밍: {environment}-{name_domain}-{name_service}-{역할}
# 엑셀 기준: suffix 없음 (vpc, alb, waf 등), SG는 {base}-{역할}-sg 패턴
locals {
  name_base = "${var.environment}-${var.name_domain}-${var.name_service}"

  name_vpc          = "${local.name_base}-vpc"
  name_s3_endpoint  = "${local.name_base}-s3-endpoint"
  name_alb          = substr("${local.name_base}-${var.alb_role_name}", 0, 32)
  name_target_group = substr("${local.name_base}-${var.alb_role_name}-tg", 0, 32)

  # WAF: ACL은 {base}-waf, IP Set은 {base}-ipset
  name_waf_acl   = "${local.name_base}-waf"
  name_waf_ipset = "${local.name_base}-ipset"

  # SG: {base}-{역할}-sg
  name_sg_alb     = "${local.name_base}-alb-sg"
  name_sg_was     = "${local.name_base}-${var.ec2_role_name}-sg"
  name_sg_bastion = "${local.name_base}-${var.bastion_role_name}-sg"
  name_sg_rds     = "${local.name_base}-rds-sg"

  # IAM Role: {base}-{역할}-role
  name_iam_was     = "${local.name_base}-${var.ec2_role_name}-role"
  name_iam_bastion = "${local.name_base}-${var.bastion_role_name}-role"

  iam_prefix = substr("${local.name_base}-", 0, 28)

  tags = merge(var.additional_tags, {
    project = var.project_name
    env     = var.environment
    domain  = var.name_domain
    service = var.name_service
    owner   = var.tag_owner
  })

  waf_ipv4_normalized = [
    for a in var.waf_allowed_ipv4_cidr : strcontains(a, "/") ? trimspace(a) : "${trimspace(a)}/32"
  ]
}
