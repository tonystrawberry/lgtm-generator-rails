resource "aws_ecr_repository" "aws_ecr_repository" {
  name = "lgtm-tonystrawberry-codes"
}

resource "aws_lambda_function" "aws_lambda_function" {
  function_name = "lgtm-tonystrawberry-codes"
  timeout       = 15 * 60 # 15 minutes
  memory_size = 2048
  image_uri     = "${aws_ecr_repository.aws_ecr_repository.repository_url}:${var.tag}"
  package_type  = "Image"

  role = aws_iam_role.aws_iam_role.arn
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

resource "aws_iam_policy" "aws_iam_policy" {
  name = "lgtm-tonystrawberry-codes-iam-policy"

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

resource "aws_dynamodb_table" "aws_dynamodb_table" {
  name           = "lgtm-tonystrawberry-codes"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "id"
  attribute {
    name = "id"
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
