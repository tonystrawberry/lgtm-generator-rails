resource "aws_ecr_repository" "aws_ecr_repository" {
  name = "lgtm-tonystrawberry-codes"
}

resource "aws_lambda_function" "lgtm_job_aws_lambda_function" {
  function_name = "lgtm-tonystrawberry-codes-job"
  timeout       = 15 * 60 # 15 minutes
  memory_size = 2048
  image_uri     = "${aws_ecr_repository.aws_ecr_repository.repository_url}:${var.tag}"
  package_type  = "Image"

  role = aws_iam_role.lgtm_job_aws_iam_role.arn

  environment {
    variables = {
      GIPHY_API_KEY = var.giphy_api_key
      UNSPLASH_API_KEY = var.unsplash_api_key
    }
  }
}

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

resource "aws_iam_role_policy_attachment" "lgtm_job_aws_iam_role_policy_attachment" {
  role       = aws_iam_role.lgtm_job_aws_iam_role.name
  policy_arn = aws_iam_policy.lgtm_job_aws_iam_policy.arn
}

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

resource "aws_s3_bucket" "aws_s3_bucket" {
  bucket = "lgtm-tonystrawberry-codes"
}

resource "aws_s3_bucket_public_access_block" "aws_s3_bucket_public_access_block" {
  bucket                  = aws_s3_bucket.aws_s3_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "aws_s3_bucket_policy" {
  bucket = aws_s3_bucket.aws_s3_bucket.id
  policy = data.aws_iam_policy_document.aws_iam_policy_document.json
}

data "aws_iam_policy_document" "aws_iam_policy_document" {
  # OAI からのアクセスのみ許可
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
      values   = [aws_cloudfront_distribution.aws_cloudfront_distribution.arn]
    }

  }
}

resource "aws_cloudfront_distribution" "aws_cloudfront_distribution" {
  enabled = true

  # オリジンの設定
  origin {
    origin_id   = aws_s3_bucket.aws_s3_bucket.id
    domain_name = aws_s3_bucket.aws_s3_bucket.bucket_regional_domain_name

    # OAI を設定
    origin_access_control_id = aws_cloudfront_origin_access_control.aws_cloudfront_origin_access_control.id
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  default_cache_behavior {
    target_origin_id       = aws_s3_bucket.aws_s3_bucket.id
    viewer_protocol_policy = "redirect-to-https"
    cached_methods         = ["GET", "HEAD"]
    allowed_methods        = ["GET", "HEAD"]
    forwarded_values {
      query_string = false
      headers      = []
      cookies {
        forward = "none"
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
}

resource "aws_cloudfront_origin_access_control" "aws_cloudfront_origin_access_control" {
  name                              = "lgtm-tonystrawberry-codes"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}


data "archive_file" "lgtm_api_archive_file" {
  type        = "zip"
  source_dir  = "${path.module}/lambda-api"
  output_path = "${path.module}/lambda-api.zip"
}

resource "aws_lambda_function" "lgtm_api_aws_lambda_function" {
  function_name    = "lgtm-tonystrawberry-codes-fetch"
  handler          = "lgtm_fetch.lambda_handler"
  runtime          = "ruby3.2"
  filename         = data.archive_file.lgtm_api_archive_file.output_path
  source_code_hash = filebase64sha256(data.archive_file.lgtm_api_archive_file.output_path)
  role = aws_iam_role.lgtm_api_aws_iam_role.arn

  environment {
    variables = {
      CLOUDFRONT_DISTRIBUTION_URL = aws_cloudfront_distribution.aws_cloudfront_distribution.domain_name
    }
  }
}

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

resource "aws_iam_role_policy_attachment" "lgtm_api_aws_iam_role_policy_attachment" {
  role       = aws_iam_role.lgtm_api_aws_iam_role.name
  policy_arn = aws_iam_policy.lgtm_api_aws_iam_policy.arn
}

resource "aws_cloudwatch_log_group" "lgtm_api_aws_cloudwatch_log_group" {
  name = "/aws/lambda/${aws_lambda_function.lgtm_api_aws_lambda_function.function_name}"
  retention_in_days = 30
}

################################
# API Gateway
################################

resource "aws_api_gateway_rest_api" "lgtm_api_aws_api_gateway_rest_api" {
  name = "lgtm-tonystrawberry-codes-api"

  body = jsonencode({
    openapi = "3.0.1"
    info = {
      title   = "api"
      version = "1.0"
    }
    paths = {
      "/api/v1/images" = {
        get = {
          x-amazon-apigateway-integration = {
            httpMethod           = "POST"
            payloadFormatVersion = "1.0"
            type                 = "AWS_PROXY"
            uri                  = aws_lambda_function.lgtm_api_aws_lambda_function.invoke_arn
            credentials          = aws_iam_role.lgtm_api_gateway_aws_iam_role.arn
          }
        }
      }
    }
  })
}

resource "aws_api_gateway_deployment" "lgtm_api_aws_api_gateway_deployment" {
  rest_api_id = aws_api_gateway_rest_api.lgtm_api_aws_api_gateway_rest_api.id
  depends_on  = [aws_api_gateway_rest_api.lgtm_api_aws_api_gateway_rest_api]
  stage_name  = "production"
  triggers = {
    # resource "aws_lambda_function" "api" の内容が変わるごとにデプロイされるようにする
    redeployment = sha1(jsonencode(aws_api_gateway_rest_api.lgtm_api_aws_api_gateway_rest_api))
  }
}

data "aws_iam_policy_document" "lgtm_api_aws_iam_policy_document" {
  statement {
    effect = "Allow"
    principals {
      type = "*"
      identifiers = ["*"]
    }
    actions   = ["execute-api:Invoke"]
    resources = ["${aws_api_gateway_rest_api.lgtm_api_aws_api_gateway_rest_api.execution_arn}/*/*"]
  }
}

resource "aws_api_gateway_rest_api_policy" "lgtm_api_aws_api_gateway_rest_api_policy" {
  rest_api_id = aws_api_gateway_rest_api.lgtm_api_aws_api_gateway_rest_api.id
  policy = data.aws_iam_policy_document.lgtm_api_aws_iam_policy_document.json
}

################################
# API GatewayにアタッチするIAM Role
################################

resource "aws_iam_role" "lgtm_api_gateway_aws_iam_role" {
  name               = "lgtm-tonystrawberry-codes-api-gateway-role"
  assume_role_policy = data.aws_iam_policy_document.lgtm_api_gateway_aws_iam_policy_document.json
}

resource "aws_iam_role_policy_attachment" "lgtm_api_gateway_aws_iam_role_policy_attachment_cloudwatch" {
  role       = aws_iam_role.lgtm_api_gateway_aws_iam_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}

resource "aws_iam_role_policy_attachment" "lgtm_api_gateway_aws_iam_role_policy_attachment_lambda" {
  role       = aws_iam_role.lgtm_api_gateway_aws_iam_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaRole"
}

data "aws_iam_policy_document" "lgtm_api_gateway_aws_iam_policy_document" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"
    principals {
      type        = "Service"
      identifiers = ["apigateway.amazonaws.com"]
    }
  }
}
