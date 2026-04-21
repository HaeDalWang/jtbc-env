# CloudFront + OAC — stg-news-metaj-s3-svc 바라봄
# 도메인/ACM 없이 생성, 나중에 CNAME + 인증서 추가 예정

# --- OAC (Origin Access Control) ---
resource "aws_cloudfront_origin_access_control" "svc" {
  name                              = "${local.name_base}-cf-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# --- CloudFront Function (viewer-request: /metaj/private/ IP 접근 제어) ---
resource "aws_cloudfront_function" "ip_guard" {
  name    = "${local.name_base}-cf-func"
  runtime = "cloudfront-js-2.0"
  publish = true

  code = <<-EOT
    function handler(event) {
      var request = event.request;
      var clientIP = event.viewer.ip;
      var uri = request.uri;

      if (!uri.startsWith('/metaj/private/')) {
        return request;
      }

      var allowedCIDRs = [
        '203.249.146.34/32',
        '1.209.9.204/32',
        '203.249.146.39/32',
        '1.209.9.166/32',
        '1.209.9.201/32'
      ];

      function ipToLong(ip) {
        var parts = ip.split('.');
        return ((parts[0] << 24) | (parts[1] << 16) | (parts[2] << 8) | parts[3]) >>> 0;
      }

      function isInCIDR(ip, cidr) {
        var parts = cidr.trim().split('/');
        var network = ipToLong(parts[0]);
        var bits = parseInt(parts[1], 10);
        var mask = bits === 0 ? 0 : (0xFFFFFFFF << (32 - bits)) >>> 0;
        return (ipToLong(ip) & mask) === (network & mask);
      }

      for (var i = 0; i < allowedCIDRs.length; i++) {
        if (isInCIDR(clientIP, allowedCIDRs[i])) {
          return request;
        }
      }

      return {
        statusCode: 403,
        statusDescription: 'Forbidden',
        headers: {
          'content-type': { value: 'application/json' }
        },
        body: '{"error":"Access denied. Internal network only."}'
      };
    }
  EOT
}

# --- CloudFront Distribution ---
resource "aws_cloudfront_distribution" "svc" {
  enabled             = true
  comment             = "${local.name_base}-cf"
  default_root_object = "index.html"

  origin {
    domain_name              = aws_s3_bucket.buckets["svc"].bucket_regional_domain_name
    origin_id                = "${local.name_base}-s3-svc"
    origin_access_control_id = aws_cloudfront_origin_access_control.svc.id
  }

  default_cache_behavior {
    target_origin_id       = "${local.name_base}-s3-svc"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    cache_policy_id          = "658327ea-f89d-4fab-a63d-7e88639e58f6" # CachingOptimized
    origin_request_policy_id = "59781a5b-3903-41f3-afcb-af62929ccde1" # CORS-S3Origin

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.ip_guard.arn
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Name = "${local.name_base}-cf"
  }
}

# --- S3 버킷 정책: OAC만 허용 ---
resource "aws_s3_bucket_policy" "svc" {
  bucket = aws_s3_bucket.buckets["svc"].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "AllowCloudFrontOAC"
      Effect = "Allow"
      Principal = {
        Service = "cloudfront.amazonaws.com"
      }
      Action   = "s3:GetObject"
      Resource = "${aws_s3_bucket.buckets["svc"].arn}/*"
      Condition = {
        StringEquals = {
          "AWS:SourceArn" = aws_cloudfront_distribution.svc.arn
        }
      }
    }]
  })
}
