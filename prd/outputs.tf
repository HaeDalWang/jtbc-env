output "bastion_public_ip" {
  description = "바스티온 퍼블릭 IP"
  value       = aws_instance.bastion.public_ip
}

output "bastion_instance_id" {
  description = "바스티온 인스턴스 ID"
  value       = aws_instance.bastion.id
}

output "alb_dns_name" {
  description = "ALB DNS 이름"
  value       = aws_lb.app.dns_name
}

output "rds_endpoint" {
  description = "RDS 접속 엔드포인트"
  value       = aws_db_instance.main.endpoint
}

output "s3_bucket_svc" {
  description = "서비스용 S3 버킷 이름"
  value       = aws_s3_bucket.buckets["svc"].bucket
}

output "s3_bucket_adm" {
  description = "관리자용 S3 버킷 이름"
  value       = aws_s3_bucket.buckets["adm"].bucket
}

output "cloudwatch_dashboard_name" {
  description = "CloudWatch 운영 대시보드 이름"
  value       = aws_cloudwatch_dashboard.ops.dashboard_name
}

output "cloudfront_domain" {
  description = "CloudFront 배포 도메인 (임시, CNAME 설정 전)"
  value       = aws_cloudfront_distribution.svc.domain_name
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}
