# 네이밍: {environment}-{name_domain}-{name_service}-{역할}{01|02|…}
# 예: stage-news-metaj-was01, stage-news-metaj-bastion01, stage-news-metaj-cms01
locals {
  name_base = "${var.environment}-${var.name_domain}-${var.name_service}"

  # 단일 리소스(첫 번째) — 확장 시 동일 패턴으로 02, 03 …
  name_suffix_01 = format("%02d", 1)

  name_vpc          = "${local.name_base}-vpc${local.name_suffix_01}"
  name_s3_endpoint  = "${local.name_base}-s3${local.name_suffix_01}"
  name_alb          = substr(replace("${local.name_base}-${var.alb_role_name}${local.name_suffix_01}", "--", "-"), 0, 32)
  name_target_group = substr(replace("${local.name_base}-tg${local.name_suffix_01}", "--", "-"), 0, 32)

  name_waf_ipset = substr(replace("${local.name_base}-waf${local.name_suffix_01}-allow-ipv4", "--", "-"), 0, 128)
  name_waf_acl   = substr(replace("${local.name_base}-waf${local.name_suffix_01}", "--", "-"), 0, 128)

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
