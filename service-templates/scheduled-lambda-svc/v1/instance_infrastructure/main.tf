resource "aws_cloudwatch_event_rule" "lambda_schedule" {
  name                = "${var.service_instance.name}-lambda-schedule"
  schedule_expression = var.service_instance.inputs.schedule_expression
}

resource "aws_cloudwatch_event_target" "lambda_schedule_target" {
  rule = aws_cloudwatch_event_rule.lambda_schedule.name
  arn  = aws_lambda_function.function.arn
}

resource "aws_lambda_function" "function" {
  function_name = "${var.service_instance.name}-function"
  role          = aws_iam_role.iam_for_lambda.arn

  handler = local.using_default_lambda_code ? var.service_instance.inputs.lambda_handler : "index.handler"
  runtime = var.service_instance.inputs.lambda_runtime
  memory_size = var.service_instance.inputs.lambda_memory
  timeout = var.service_instance.inputs.lambda_timeout

  # Specificy either the custom lambda code location in s3, or path to the default code otherwise.
  s3_bucket = try(var.service_instance.inputs.code_bucket, null)
  s3_key    = try(var.service_instance.inputs.code_object_key, null)
  filename  = try(var.service_instance.inputs.code_bucket, false) ? null : data.archive_file.inline_lambda_code.output_path

  environment {
    variables = {
      SNSTopic = var.environment.outputs.sns_topic_name
    }
  }

  vpc_config {
    security_group_ids = [var.environment.outputs.vpc_default_security_group]
    subnet_ids         = var.service_instance.inputs.subnet_type == "private" ? [
      var.environment.outputs.private_subnet_one_id,
      var.environment.outputs.private_subnet_two_id
    ] : [
      var.environment.outputs.public_subnet_one_id,
      var.environment.outputs.public_subnet_two_id
    ]
  }
}

resource "aws_iam_role" "iam_for_lambda" {
  name = "${var.service_instance.name}-lambda-execution-role"

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

  inline_policy {
    name = "sns_publish_message_policy"
    policy = jsonencode({
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Action": [
            "sns:Publish"
          ],
          "Resource": "arn:${local.partition}:sns:${var.environment.outputs.sns_region}:${local.account_id}:${var.environment.outputs.sns_topic_name}"
        }
      ]
    })
  }

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
  ]
}

resource "aws_lambda_permission" "lambda-trigger-permissions" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.function.function_name
  principal     = "events.amazonaws.com"
  source_arn = aws_cloudwatch_event_rule.lambda_schedule.arn
}
