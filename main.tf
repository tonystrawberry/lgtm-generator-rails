data "aws_ecr_repository" "aws_ecr_repository" {
  name = "lgtm-tonystrawberry-codes"
}

resource "aws_lambda_function" "aws_lambda_function" {
  function_name = "lgtm-tonystrawberry-codes"
  timeout       = 5 # seconds
  image_uri     = "${data.aws_ecr_repository.aws_ecr_repository.repository_url}:latest"
  package_type  = "Image"

  role = aws_iam_role.profile_faker_function_role.arn
}

resource "aws_iam_role" "aws_iam_role" {
  name = "lgtm-tonystrawberry-codes-iam-role"

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
