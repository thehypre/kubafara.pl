terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  required_version = ">= 1.7.4"
}

provider "aws" {
  region = "eu-central-1"
}

#dynamodb table
# resource "aws_dynamodb_table" "kubafara-views-db" {
#   name           = "kubafara-views-db"
#   billing_mode   = "PROVISIONED"
#   read_capacity  = 20
#   write_capacity = 20
#   hash_key       = "id"

#   attribute {
#     name = "id"
#     type = "S"
#   }

#   attribute {
#     name = "view_count"
#     type = "S"
#   }

#   global_secondary_index {
#     name            = "view_count_index"
#     hash_key        = "view_count"
#     projection_type = "ALL"
#     read_capacity   = 10
#     write_capacity  = 10
#   }

#   tags = {
#     Name = "kubafara-pl"
#   }
# }

# resource "aws_dynamodb_table_item" "kubafara-views-db" {
#   table_name = aws_dynamodb_table.kubafara-views-db.name
#   hash_key   = aws_dynamodb_table.kubafara-views-db.hash_key

#   item = <<ITEM
# {
#   "id": {"S": "1"},
#   "view_count": {"S": "1"}
# }
# ITEM
#   lifecycle {
#     ignore_changes = all
#   }
# }

#iam roles for the lambda func
resource "aws_iam_role" "lambda_role" {
  name = "terraform_lambda_func_Role"
  assume_role_policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Action" : "sts:AssumeRole",
          "Principal" : {
            "Service" : "lambda.amazonaws.com"
          },
          "Effect" : "Allow",
          "Sid" : ""
        }
      ]
  })
}

resource "aws_iam_policy" "iam_policy_for_lambda" {
  name        = "aws_iam_policy_for_terraform_lambda_func_role"
  path        = "/"
  description = "AWS IAM Policy for managing aws lambda role"
  policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Action" : [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents"
          ],
          "Resource" : "arn:aws:logs:*:*:*",
          "Effect" : "Allow"
        },
        {
          "Effect" : "Allow",
          "Action" : [
            "dynamodb:UpdateItem",
            "dynamodb:GetItem",
            "dynamodb:PutItem"
          ],
          "Resource" : "arn:aws:dynamodb:*:*:table/kubafara-views"
        },
      ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_iam_policy_to_iam_role" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.iam_policy_for_lambda.arn
}


#zip + lambda

data "archive_file" "zip_the_python_code" {
  type        = "zip"
  source_dir  = "${path.module}/lambda-function/"
  output_path = "${path.module}/lambda-function/lambda_function.zip"
}

resource "aws_lambda_function" "terraform_lambda_func" {
  filename      = "${path.module}/lambda-function/lambda_function.zip"
  function_name = "terraform_lambda_func"
  role          = aws_iam_role.lambda_role.arn
  handler       = "terraform_lambda_func.lambda_handler"
  runtime       = "python3.12"
  depends_on    = [aws_iam_role_policy_attachment.attach_iam_policy_to_iam_role]
  environment {
    variables = {
      databaseName = "kubafara-views"
    }
  }
}

#cw+api

# resource "aws_cloudwatch_log_group" "api_gw" {
#   name              = "visitor_count_log_group"
#   retention_in_days = 30
# }

# resource "aws_apigatewayv2_api" "lambda" {
#   name          = "visitor_count_CRC"
#   protocol_type = "HTTP"
#   description   = "Visitor count for kubafara-pl"
#   cors_configuration {
#     allow_origins = ["https://kubafara.pl", "https://www.kubafara.pl"]
#   }
# }

# #api gw stage and deploy
# resource "aws_apigatewayv2_stage" "lambda" {
#   api_id = aws_apigatewayv2_api.lambda.id

#   name        = "default"
#   auto_deploy = true

#   access_log_settings {
#     destination_arn = aws_cloudwatch_log_group.api_gw.arn

#     format = jsonencode({
#       requestId               = "$context.requestId"
#       sourceIp                = "$context.identity.sourceIp"
#       requestTime             = "$context.requestTime"
#       protocol                = "$context.protocol"
#       httpMethod              = "$context.httpMethod"
#       resourcePath            = "$context.resourcePath"
#       routeKey                = "$context.routeKey"
#       status                  = "$context.status"
#       responseLength          = "$context.responseLength"
#       integrationErrorMessage = "$context.integrationErrorMessage"
#     })
#   }

#   tags = {
#     Name = "kubafara-pl"
#   }
# }

# #api gw integration with lambda func
# resource "aws_apigatewayv2_integration" "terraform_lambda_func" {
#   api_id             = aws_apigatewayv2_api.lambda.id
#   integration_uri    = aws_lambda_function.terraform_lambda_func.invoke_arn
#   integration_type   = "AWS_PROXY"
#   integration_method = "POST"
# }

# #api gw route
# resource "aws_apigatewayv2_route" "terraform_lambda_func" {
#   api_id    = aws_apigatewayv2_api.lambda.id
#   route_key = "ANY /terraform_lambda_func"
#   target    = "integrations/${aws_apigatewayv2_integration.terraform_lambda_func.id}"
# }

# #lambda permission to API gw
# resource "aws_lambda_permission" "api_gw" {
#   statement_id  = "AllowExecutionFromAPIGateway"
#   action        = "lambda:InvokeFunction"
#   function_name = aws_lambda_function.terraform_lambda_func.function_name
#   principal     = "apigateway.amazonaws.com"
#   source_arn    = "${aws_apigatewayv2_api.lambda.execution_arn}/*/*"
# }

resource "aws_lambda_function_url" "url1" {
  function_name      = aws_lambda_function.terraform_lambda_func.function_name
  authorization_type = "NONE"

  cors {
    allow_credentials = true
    allow_origins     = ["*"]
    allow_methods     = ["*"]
    allow_headers     = ["date", "keep-alive"]
    expose_headers    = ["keep-alive", "date"]
    max_age           = 86400
  }
}


#add s3 and table from here, 