# Create EventBridge rule to trigger Lambda function every hour
resource "aws_cloudwatch_event_rule" "lgtm_job_aws_cloudwatch_event_rule" {
  name        = "lgtm-tonystrawberry-codes-job"
  description = "EventBridge rule to trigger `lgtm-tonystrawberry-codes-job` Lambda function every hour"
  schedule_expression = "cron(0 * * * ? *)"
}

# Create a target for the EventBridge rule to trigger the Lambda function with a payload
resource "aws_cloudwatch_event_target" "lgtm_job_aws_cloudwatch_event_target" {
  rule      = aws_cloudwatch_event_rule.lgtm_job_aws_cloudwatch_event_rule.name
  arn       = var.lgtm_job_aws_lambda_function_arn
  target_id = "lgtm-tonystrawberry-codes-job"

  input = <<JSON
{
  "keyword": "lgtm",
  "source": "giphy"
}
JSON
}

# Create a Lambda permission to allow EventBridge to invoke the Lambda function
resource "aws_lambda_permission" "lgtm_job_aws_lambda_permission" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = var.lgtm_job_aws_lambda_function_name # aws_lambda_function.lgtm_job_aws_lambda_function.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.lgtm_job_aws_cloudwatch_event_rule.arn
}
