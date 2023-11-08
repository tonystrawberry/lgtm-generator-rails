module "api-gateway" {
  source = "./modules/api-gateway"

  lgtm_api_aws_lambda_function_invoke_arn = module.lambda.lgtm_api_aws_lambda_function_invoke_arn
}

module "cloudfront" {
  source = "./modules/cloudfront"

  s3_bucket_id = module.storage.s3_bucket_id
  s3_bucket_regional_domain_name = module.storage.s3_bucket_regional_domain_name
}

module "eventbridge" {
  source = "./modules/eventbridge"

  lgtm_job_aws_lambda_function_arn = module.lambda.lgtm_job_aws_lambda_function_arn
  lgtm_job_aws_lambda_function_name = module.lambda.lgtm_job_aws_lambda_function_name
}

module "ecr" {
  source = "./modules/ecr"
}

module "lambda" {
  source = "./modules/lambda"

  giphy_api_key = var.giphy_api_key
  unsplash_api_key = var.unsplash_api_key
  tag = var.tag
  aws_ecr_repository_url = module.ecr.aws_ecr_repository_url
  aws_cloudfront_distribution_domain_name = module.cloudfront.aws_cloudfront_distribution_domain_name
}

module "storage" {
  source = "./modules/storage"

  aws_cloudfront_distribution_arn = module.cloudfront.aws_cloudfront_distribution_arn
}
