variable "aws_cloudfront_distribution_arn" {
  description = "ARN of the CloudFront distribution"
  type = string
}

variable "opensearch_enabled" {
  description = "Whether to enable OpenSearch"
  type = bool
}
