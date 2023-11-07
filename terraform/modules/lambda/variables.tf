variable "giphy_api_key" {
  description = "Giphy API key"
  type = string
}

variable "unsplash_api_key" {
  description = "Unsplash API key"
  type = string
}

variable "tag" {
  description = "Tag of the Docker image to deploy"
  type = string
}

variable "aws_ecr_repository_url" {
  description = "URL of the ECR repository"
  type = string
}

variable "aws_cloudfront_distribution_domain_name" {
  description = "Domain name of the CloudFront distribution"
  type = string
}
