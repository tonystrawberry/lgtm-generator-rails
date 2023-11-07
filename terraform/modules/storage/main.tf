# Create a DynamoDB table to store the images metadata
resource "aws_dynamodb_table" "aws_dynamodb_table" {
  name           = "lgtm-tonystrawberry-codes"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "id"
  range_key      = "source"
  attribute {
    name = "id"
    type = "S"
  }

  attribute {
    name = "source"
    type = "S"
  }

  attribute {
    name = "created_at"
    type = "S"
  }

  attribute {
    name = "status"
    type = "S"
  }
  global_secondary_index {
    name               = "status-created_at-index"
    hash_key           = "status"
    range_key = "created_at"
    projection_type    = "ALL"
  }
}

# Create S3 bucket to store the images
resource "aws_s3_bucket" "aws_s3_bucket" {
  bucket = "lgtm-tonystrawberry-codes"
}

# Create S3 bucket public access block (block public access)
resource "aws_s3_bucket_public_access_block" "aws_s3_bucket_public_access_block" {
  bucket                  = aws_s3_bucket.aws_s3_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Attach S3 bucket policy to allow CloudFront to access the bucket
resource "aws_s3_bucket_policy" "aws_s3_bucket_policy" {
  bucket = aws_s3_bucket.aws_s3_bucket.id
  policy = data.aws_iam_policy_document.aws_iam_policy_document.json
}

# Only allow CloudFront to access the bucket
data "aws_iam_policy_document" "aws_iam_policy_document" {
  statement {
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.aws_s3_bucket.arn}/*"]
    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = [var.aws_cloudfront_distribution_arn]
    }

  }
}
