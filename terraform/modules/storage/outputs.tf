output "s3_bucket_id" {
  value = aws_s3_bucket.aws_s3_bucket.id
}

output "s3_bucket_regional_domain_name" {
  value = aws_s3_bucket.aws_s3_bucket.bucket_regional_domain_name
}
