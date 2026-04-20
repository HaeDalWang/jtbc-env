# 네이밍: {environment}-{name_domain}-{name_service}-{리소스 역할}
# 예: stage-news-metaj-was-1, stage-news-metaj-cms, stage-news-metaj-s3
locals {
  name_base = "${var.environment}-${var.name_domain}-${var.name_service}"

  name_vpc          = "${local.name_base}-vpc"
  name_s3_endpoint  = "${local.name_base}-s3"
  name_alb          = substr(replace("${local.name_base}-${var.alb_role_name}", "--", "-"), 0, 32)
  name_target_group = substr(replace("${local.name_base}-tg-${var.ec2_role_name}", "--", "-"), 0, 32)

  name_waf_ipset = substr(replace("${local.name_base}-waf-allow-ipv4", "--", "-"), 0, 128)
  name_waf_acl   = substr(replace("${local.name_base}-waf", "--", "-"), 0, 128)

  # IAM / SG name_prefix 길이 완화
  iam_prefix = substr(replace("${local.name_base}-", "--", "-"), 0, 28)

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
