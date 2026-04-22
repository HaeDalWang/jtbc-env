# ACM 인증서 — *.jtbc.co.kr 와일드카드 (STG에서 이미 발급된 ARN 참조)
# PRD도 동일 와일드카드 인증서 사용

# --- CloudFront용 ACM (us-east-1) ---
data "aws_acm_certificate" "cloudfront" {
  provider = aws.us_east_1

  domain      = "*.jtbc.co.kr"
  statuses    = ["ISSUED"]
  most_recent = true
}

# --- ALB용 ACM (ap-northeast-2) ---
data "aws_acm_certificate" "alb" {
  domain      = "*.jtbc.co.kr"
  statuses    = ["ISSUED"]
  most_recent = true
}
