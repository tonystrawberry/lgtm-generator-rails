###########################
### Lambda JOB Function ###
###########################

# Create Lambda function that will be triggered by CloudWatch Events
# It will run once per hour and get the latest image from Giphy
resource "aws_lambda_function" "lgtm_job_aws_lambda_function" {
  function_name = "lgtm-tonystrawberry-codes-job"
  timeout       = 15 * 60 # 15 minutes
  memory_size = 2048
  image_uri     = "${var.aws_ecr_repository_url}:${var.tag}"
  package_type  = "Image"

  role = aws_iam_role.lgtm_job_aws_iam_role.arn

  environment {
    variables = {
      GIPHY_API_KEY = var.giphy_api_key
      UNSPLASH_API_KEY = var.unsplash_api_key
    }
  }
}

# Create IAM Role for Lambda JOB function
resource "aws_iam_role" "lgtm_job_aws_iam_role" {
  name = "lgtm-tonystrawberry-codes-job-iam-role"

  assume_role_policy = jsonencode({
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
    ]
  })
}

# Create IAM Policy for Lambda JOB function
# Allow Lambda function to write to CloudWatch Logs
# Allow Lambda function to read/write to S3
# Allow Lambda function to read/write to DynamoDB
resource "aws_iam_policy" "lgtm_job_aws_iam_policy" {
  name = "lgtm-tonystrawberry-codes-job-iam-policy"

  policy = <<EOF
{
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Action": [
            "logs:*"
          ],
          "Resource": "arn:aws:logs:*:*:*"
        },
        {
          "Effect": "Allow",
          "Action": [
            "s3:*"
          ],
          "Resource": "arn:aws:s3:::*"
        },
        {
          "Effect": "Allow",
          "Action": [
            "dynamodb:*"
          ],
          "Resource": "arn:aws:dynamodb:*:*:*"
        }
      ]
}
    EOF
}

# Attach IAM Policy to IAM Role for Lambda JOB function
resource "aws_iam_role_policy_attachment" "lgtm_job_aws_iam_role_policy_attachment" {
  role       = aws_iam_role.lgtm_job_aws_iam_role.name
  policy_arn = aws_iam_policy.lgtm_job_aws_iam_policy.arn
}

###########################
### Lambda API Function ###
###########################

# The Lambda function contents are in the lambda-api directory
data "archive_file" "lgtm_api_archive_file" {
  type        = "zip"
  source_dir  = "${path.root}/lambda-api"
  output_path = "${path.root}/lambda-api.zip"
}

# Create Lambda function that will be triggered by API Gateway
# It will get the images metadata from DynamoDB and return it to the user
resource "aws_lambda_function" "lgtm_api_aws_lambda_function" {
  function_name    = "lgtm-tonystrawberry-codes-fetch"
  handler          = "lgtm_fetch.lambda_handler"
  runtime          = "ruby3.2"
  filename         = data.archive_file.lgtm_api_archive_file.output_path
  source_code_hash = filebase64sha256(data.archive_file.lgtm_api_archive_file.output_path)
  role = aws_iam_role.lgtm_api_aws_iam_role.arn
  timeout          = 30 # 30 seconds

  environment {
    variables = {
      CLOUDFRONT_DISTRIBUTION_URL = var.aws_cloudfront_distribution_domain_name
    }
  }
}

# Create IAM Role for Lambda API function
resource "aws_iam_role" "lgtm_api_aws_iam_role" {
  name = "lgtm-tonystrawberry-codes-api-iam-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

# Create IAM Policy for Lambda API function
# Allow Lambda function to write to CloudWatch Logs
# Allow Lambda function to read/write to DynamoDB
resource "aws_iam_policy" "lgtm_api_aws_iam_policy" {
  name = "lgtm-tonystrawberry-codes-api-iam-policy"
  description = "IAM policy for the API Lambda function"

  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = [
          aws_cloudwatch_log_group.lgtm_api_aws_cloudwatch_log_group.arn,
          "${aws_cloudwatch_log_group.lgtm_api_aws_cloudwatch_log_group.arn}:*"
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "dynamodb:*"
        ]
        Resource = "arn:aws:dynamodb:*:*:*"
      }
    ]
  })
}

# Attach IAM Policy to IAM Role for Lambda API function
resource "aws_iam_role_policy_attachment" "lgtm_api_aws_iam_role_policy_attachment" {
  role       = aws_iam_role.lgtm_api_aws_iam_role.name
  policy_arn = aws_iam_policy.lgtm_api_aws_iam_policy.arn
}

# Create CloudWatch Log Group for Lambda API function
resource "aws_cloudwatch_log_group" "lgtm_api_aws_cloudwatch_log_group" {
  name = "/aws/lambda/${aws_lambda_function.lgtm_api_aws_lambda_function.function_name}"
  retention_in_days = 30
}
