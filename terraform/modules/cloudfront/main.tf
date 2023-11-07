# Create a CloudFront distribution to serve the images
resource "aws_cloudfront_distribution" "aws_cloudfront_distribution" {
  enabled = true

  # オリジンの設定
  origin {
    origin_id   = var.s3_bucket_id
    domain_name = var.s3_bucket_regional_domain_name

    # OAI を設定
    origin_access_control_id = aws_cloudfront_origin_access_control.aws_cloudfront_origin_access_control.id
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  default_cache_behavior {
    target_origin_id       = var.s3_bucket_id
    viewer_protocol_policy = "redirect-to-https"
    cached_methods         = ["GET", "HEAD"]
    allowed_methods        = ["GET", "HEAD"]
    forwarded_values {
      query_string = false
      headers      = []
      cookies {
        forward = "none"
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
}

# Create an Origin Access Identity (OAI) for CloudFront to access the S3 bucket
resource "aws_cloudfront_origin_access_control" "aws_cloudfront_origin_access_control" {
  name                              = "lgtm-tonystrawberry-codes"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}
