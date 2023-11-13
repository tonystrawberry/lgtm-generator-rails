output "s3_bucket_id" {
  value = aws_s3_bucket.aws_s3_bucket.id
}

output "s3_bucket_regional_domain_name" {
  value = aws_s3_bucket.aws_s3_bucket.bucket_regional_domain_name
}

output "dynamo_db_stream_arn" {
  value = aws_dynamodb_table.aws_dynamodb_table.stream_arn
}
