# ACM 인증서 — *.jtbc.co.kr 와일드카드
# - CloudFront용: us-east-1 (버지니아 필수)
# - ALB용: ap-northeast-2 (서울)
# DNS 검증 방식 — 아카마이 팀에 CNAME 레코드 추가 요청 필요

# --- CloudFront용 ACM (us-east-1) ---
resource "aws_acm_certificate" "cloudfront" {
  provider = aws.us_east_1

  domain_name       = "*.jtbc.co.kr"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${local.name_base}-acm-cf"
  }
}

# --- ALB용 ACM (ap-northeast-2) ---
resource "aws_acm_certificate" "alb" {
  domain_name       = "*.jtbc.co.kr"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [tags]
  }

  tags = {
    Name = "${local.name_base}-acm-alb"
  }
}
