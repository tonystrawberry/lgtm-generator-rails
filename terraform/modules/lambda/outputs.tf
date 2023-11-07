output "aws_lambda_function_invoke_arn" {
  value = aws_lambda_function.lgtm_api_aws_lambda_function.invoke_arn
}

output "aws_lambda_function_arn" {
  value = aws_lambda_function.lgtm_job_aws_lambda_function.arn
}

output "aws_lambda_function_name" {
  value = aws_lambda_function.lgtm_job_aws_lambda_function.function_name
}
