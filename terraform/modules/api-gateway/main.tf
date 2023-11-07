# Create API Gateway REST API to serve the images
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
            uri                  = var.aws_lambda_function_invoke_arn # aws_lambda_function.lgtm_api_aws_lambda_function.invoke_arn
            credentials          = aws_iam_role.lgtm_api_gateway_aws_iam_role.arn
          }
        }
      }
    }
  })
}

# Create API Gateway Deployment to deploy the API
resource "aws_api_gateway_deployment" "lgtm_api_aws_api_gateway_deployment" {
  rest_api_id = aws_api_gateway_rest_api.lgtm_api_aws_api_gateway_rest_api.id
  depends_on  = [aws_api_gateway_rest_api.lgtm_api_aws_api_gateway_rest_api]
  stage_name  = "production"
  triggers = {
    # resource "aws_lambda_function" "api" の内容が変わるごとにデプロイされるようにする
    redeployment = sha1(jsonencode(aws_api_gateway_rest_api.lgtm_api_aws_api_gateway_rest_api))
  }
}

# Create IAM Policy Document for API Gateway to allow all users to access the API
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

# Attach IAM Policy to API Gateway
resource "aws_api_gateway_rest_api_policy" "lgtm_api_aws_api_gateway_rest_api_policy" {
  rest_api_id = aws_api_gateway_rest_api.lgtm_api_aws_api_gateway_rest_api.id
  policy = data.aws_iam_policy_document.lgtm_api_aws_iam_policy_document.json
}

# Create IAM Role for API Gateway
resource "aws_iam_role" "lgtm_api_gateway_aws_iam_role" {
  name               = "lgtm-tonystrawberry-codes-api-gateway-role"
  assume_role_policy = data.aws_iam_policy_document.lgtm_api_gateway_aws_iam_policy_document.json
}

# Attach IAM Policy to IAM Role for API Gateway
# Allow API Gateway to push logs to CloudWatch Logs
resource "aws_iam_role_policy_attachment" "lgtm_api_gateway_aws_iam_role_policy_attachment_cloudwatch" {
  role       = aws_iam_role.lgtm_api_gateway_aws_iam_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}

# Attach IAM Policy to IAM Role for API Gateway
# Allow API Gateway to invoke Lambda function
resource "aws_iam_role_policy_attachment" "lgtm_api_gateway_aws_iam_role_policy_attachment_lambda" {
  role       = aws_iam_role.lgtm_api_gateway_aws_iam_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaRole"
}


# Create IAM Policy Document for API Gateway to assume the role
# Allow API Gateway to assume the STS role
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
