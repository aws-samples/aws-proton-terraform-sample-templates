data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

data "aws_iam_policy_document" "processing_queue_policy_document" {
  statement {
    effect = "Allow"
    actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage"
    ]
    principals {
      identifiers = ["lambda.amazonaws.com"]
      type        = "Service"
    }
    resources = [
      aws_sqs_queue.processing_queue.arn
    ]
  }
  statement {
    effect  = "Allow"
    actions = ["sqs:SendMessage"]
    principals {
      identifiers = ["sns.amazonaws.com"]
      type        = "Service"
    }
    resources = [
      aws_sqs_queue.processing_queue.arn
    ]

    condition {
      test     = "ArnEquals"
      values   = [var.environment.outputs.SnsTopicName]
      variable = "aws:SourceArn"
    }
  }
}

data "aws_iam_policy_document" "ecs_processing_queue_task_def_task_role_policy_document" {
  statement {
    effect = "Allow"
    actions = [
      "sqs:ReceiveMessage",
      "sqs:ChangeMessageVisibility",
      "sqs:GetQueueUrl",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes"
    ]
    resources = [
      aws_sqs_queue.processing_queue.arn
    ]
  }
}

data "archive_file" "lambda_zip_inline" {
  type        = "zip"
  output_path = "lambda_zip_inline.zip"

  source {
    filename = "index.js"
    content  = <<EOF
        exports.handler = async (event, context) => {
          try {
            // Log event and context object to CloudWatch Logs
            console.log("Event: ", JSON.stringify(event, null, 2));
            console.log("Context: ", JSON.stringify(context, null, 2));
            return {};
          } catch (error) {
            console.error(error);
            throw new Error(error);
          }
        };
EOF
  }
}
