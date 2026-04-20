# 로컬 환경변수 지정
locals {
  project             = "jtbc"
  project_prefix      = "jtbc"
  tags = {                                                             # 모든 리소스에 적용되는 전역 태그
    "project"   = local.project
  }
}