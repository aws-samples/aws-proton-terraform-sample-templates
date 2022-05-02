resource "aws_apigatewayv2_api" "lambda" {
  name          = var.service.name
  protocol_type = "HTTP"
  cors_configuration {
    allow_origins = ["*"]
    allow_methods = [
      "GET",
      "HEAD",
      "OPTIONS",
      "POST",
    ]
  }
}

resource "aws_apigatewayv2_stage" "lambda" {
  api_id      = aws_apigatewayv2_api.lambda.id
  name        = "${var.service.name}-${var.service_instance.name}-stage"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gw.arn

    format = jsonencode({
      requestId               = "$context.requestId"
      sourceIp                = "$context.identity.sourceIp"
      requestTime             = "$context.requestTime"
      protocol                = "$context.protocol"
      httpMethod              = "$context.httpMethod"
      resourcePath            = "$context.resourcePath"
      routeKey                = "$context.routeKey"
      status                  = "$context.status"
      responseLength          = "$context.responseLength"
      integrationErrorMessage = "$context.integrationErrorMessage"
    })
  }
}

resource "aws_cloudwatch_log_group" "api_gw" {
  name = "/aws/api_gw/${aws_apigatewayv2_api.lambda.name}"

  retention_in_days = 30
}

resource "aws_lambda_function" "lambda_function" {
  function_name = "${var.service.name}-${var.service_instance.name}-function"
  runtime       = var.service_instance.inputs.lambda_runtime
  role          = aws_iam_role.lambda_exec.arn

  environment {
    variables = {
      SnsTopicName = var.environment.outputs.SnsTopicName
    }
  }

  handler   = contains(keys(var.service_instance.inputs), "lambda_bucket") ? var.service_instance.inputs.lambda_handler : "index.handler"
  s3_bucket = contains(keys(var.service_instance.inputs), "lambda_bucket") ? var.service_instance.inputs.lambda_bucket : null
  s3_key    = contains(keys(var.service_instance.inputs), "lambda_bucket") ? var.service_instance.inputs.lambda_key : null
  filename  = contains(keys(var.service_instance.inputs), "lambda_bucket") ? null : data.archive_file.lambda_zip_inline.output_path
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id = aws_apigatewayv2_api.lambda.id

  integration_uri    = aws_lambda_function.lambda_function.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}

resource "aws_apigatewayv2_route" "hello_world" {
  api_id = aws_apigatewayv2_api.lambda.id

  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_function.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.lambda.execution_arn}/*/*"
}

resource "aws_iam_role" "lambda_exec" {
  name_prefix = "serverless_lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_exec_policy" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "ssn_publish_policy" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.sns_publish_policy.arn
}

resource "aws_iam_policy" "sns_publish_policy" {
  policy = data.aws_iam_policy_document.sns_publish_policy_document.json
}
