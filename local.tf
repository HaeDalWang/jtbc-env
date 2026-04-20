# 로컬 값 (이름·태그). 네이밍은 variables.tf의 project_name / environment 기준
locals {
  project        = var.project_name
  project_prefix = var.project_prefix
  name_prefix    = "${var.project_prefix}-${var.environment}"

  # ALB / Target Group 이름은 AWS 32자 제한
  alb_resource_name = substr(replace("${local.name_prefix}-alb", "--", "-"), 0, 32)
  tg_resource_name  = substr(replace("${local.name_prefix}-http80-tg", "--", "-"), 0, 32)

  tags = merge(var.additional_tags, {
    project = var.project_name
    env     = var.environment
  })

  # WAF IP 세트는 CIDR만 허용 — 슬래시가 없으면 단일 호스트로 /32 부여
  waf_ipv4_normalized = [
    for a in var.waf_allowed_ipv4_cidr : strcontains(a, "/") ? trimspace(a) : "${trimspace(a)}/32"
  ]
}
