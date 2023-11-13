# Create a OpenSearch domain
resource "aws_opensearch_domain" "lgtm_opensearch_aws_opensearch_domain" {
  domain_name           = "lgtm-tonystrawberry-codes"
  engine_version = "OpenSearch_2.9"

  cluster_config {
    instance_type = "t3.small.search"
  }

  advanced_security_options {
    enabled                        = true
    anonymous_auth_enabled         = true
    internal_user_database_enabled = true

    master_user_options {
      master_user_name     = "tonystrawberry"
      master_user_password = "Tonystrawberry123!"
    }
  }

  node_to_node_encryption {
    enabled = true
  }

  ebs_options {
    ebs_enabled = true
    volume_size = 10
  }

  encrypt_at_rest {
    enabled = true
  }

  domain_endpoint_options {
    enforce_https       = true
    tls_security_policy = "Policy-Min-TLS-1-2-2019-07"
  }
}

# The Lambda function contents are in the lambda-opensearch directory
data "archive_file" "lgtm_opensearch_archive_file" {
  type        = "zip"
  source_dir  = "${path.root}/lambda-opensearch"
  output_path = "${path.root}/lambda-opensearch.zip"
}

# Lambda function to be triggered by DynamoDB Stream
# It will index or delete the image metadata in OpenSearch
resource "aws_lambda_function" "lgtm_opensearch_aws_lambda_function" {
  function_name    = "lgtm-tonystrawberry-codes-opensearch"
  handler          = "lgtm_opensearch.lambda_handler"
  runtime          = "ruby3.2"
  filename         = data.archive_file.lgtm_opensearch_archive_file.output_path
  source_code_hash = filebase64sha256(data.archive_file.lgtm_opensearch_archive_file.output_path)
  role = aws_iam_role.lgtm_opensearch_aws_iam_role.arn
  timeout          = 30 # 30 seconds

  environment {
    variables = {
      OPENSEARCH_ENDPOINT = aws_opensearch_domain.lgtm_opensearch_aws_opensearch_domain.endpoint
    }
  }
}

# Create IAM Policy for Lambda JOB function
# Allow Lambda function to write to CloudWatch Logs
# Allow Lambda function to read/write to S3
# Allow Lambda function to read/write to DynamoDB
resource "aws_iam_policy" "lgtm_opensearch_aws_iam_policy" {
  name = "lgtm-tonystrawberry-codes-opensearch-iam-policy"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "es:ESHttpPost",
        "es:ESHttpPut",
        "dynamodb:DescribeStream",
        "dynamodb:GetRecords",
        "dynamodb:GetShardIterator",
        "dynamodb:ListStreams",
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "*"
    }
  ]
}
    EOF
}

# Attach IAM Policy to IAM Role for Lambda Opensearch function
resource "aws_iam_role_policy_attachment" "lgtm_opensearch_aws_iam_role_policy_attachment" {
  role       = aws_iam_role.lgtm_opensearch_aws_iam_role.name
  policy_arn = aws_iam_policy.lgtm_opensearch_aws_iam_policy.arn
}

# Create IAM Role for Lambda Opensearch function
resource "aws_iam_role" "lgtm_opensearch_aws_iam_role" {
  name = "lgtm-tonystrawberry-codes-opensearch-iam-role"

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

# Create a Lambda permission to allow DynamoDB to invoke the Lambda function
resource "aws_lambda_event_source_mapping" "example" {
  event_source_arn  = var.dynamo_db_stream_arn
  function_name     = aws_lambda_function.lgtm_opensearch_aws_lambda_function.function_name
  starting_position = "LATEST"
}
