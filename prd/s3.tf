# STG S3 버킷 2개: 서비스용(svc) + 관리자용(adm)

locals {
  s3_buckets = {
    svc = {
      name    = "${local.name_base}-s3-svc"
      comment = "service JSON for CloudFront OAC"
    }
    adm = {
      name    = "${local.name_base}-s3-adm"
      comment = "admin only internal IP"
    }
  }
}

resource "aws_s3_bucket" "buckets" {
  for_each = local.s3_buckets

  bucket = each.value.name

  tags = {
    Name    = each.value.name
    purpose = each.value.comment
  }
}

# 퍼블릭 액세스 전체 차단
resource "aws_s3_bucket_public_access_block" "buckets" {
  for_each = local.s3_buckets

  bucket = aws_s3_bucket.buckets[each.key].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# SSE-S3 기본 암호화
resource "aws_s3_bucket_server_side_encryption_configuration" "buckets" {
  for_each = local.s3_buckets

  bucket = aws_s3_bucket.buckets[each.key].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }

  lifecycle {
    ignore_changes = [rule]
  }
}

# 버전 관리 비활성화 (문서 기준: 사용안함)
resource "aws_s3_bucket_versioning" "buckets" {
  for_each = local.s3_buckets

  bucket = aws_s3_bucket.buckets[each.key].id

  versioning_configuration {
    status = "Disabled"
  }
}
