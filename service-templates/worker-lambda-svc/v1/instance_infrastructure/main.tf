resource "aws_sqs_queue" "dlq" {
  message_retention_seconds = 1209600
}

resource "aws_sqs_queue" "processing_queue" {
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = 3
  })
}

resource "aws_sqs_queue_policy" "processing_queue_policy" {
  policy    = data.aws_iam_policy_document.processing_queue_policy_document.json
  queue_url = aws_sqs_queue.processing_queue.id
}

resource "aws_sns_topic_subscription" "ping_topic_subscription" {
  topic_arn = var.environment.outputs.SnsTopicArn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.processing_queue.arn
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

resource "aws_iam_role_policy_attachment" "lambda_exec_vpc_policy" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_exec_sqs_policy" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaSQSQueueExecutionRole"
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

  vpc_config {
    security_group_ids = [var.environment.outputs.VpcDefaultSecurityGroupId]
    subnet_ids = var.service_instance.inputs.subnet_type == "private" ? [
      var.environment.outputs.PrivateSubnetOneId, var.environment.outputs.PrivateSubnetTwoId
      ] : [
      var.environment.outputs.PublicSubnetOneId, var.environment.outputs.PublicSubnetTwoId
    ]
  }

  handler   = contains(keys(var.service_instance.inputs), "lambda_bucket") ? var.service_instance.inputs.lambda_handler : "index.handler"
  s3_bucket = contains(keys(var.service_instance.inputs), "lambda_bucket") ? var.service_instance.inputs.lambda_bucket : null
  s3_key    = contains(keys(var.service_instance.inputs), "lambda_bucket") ? var.service_instance.inputs.lambda_key : null
  filename  = contains(keys(var.service_instance.inputs), "lambda_bucket") ? null : data.archive_file.lambda_zip_inline.output_path
}

resource "aws_lambda_event_source_mapping" "sqs_event_source" {
  event_source_arn = aws_sqs_queue.processing_queue.arn
  function_name    = aws_lambda_function.lambda_function.function_name
  batch_size       = 10

}
