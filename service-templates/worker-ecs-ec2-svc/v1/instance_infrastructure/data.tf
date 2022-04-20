data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

data "aws_iam_policy_document" "ecs_processing_queue_policy_document" {
  statement {
    effect  = "Allow"
    actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage"
    ]
    principals {
      # TODO ServiceQueueProcessingTaskDefTaskRole
      identifiers = []
      type        = "AWS"
    }
    resources = [
      aws_sqs_queue.ecs_processing_queue.arn
    ]
  }
  statement {
    effect  = "Allow"
    actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage"
    ]
    principals {
      identifiers = ["sns.amazonaws.com"]
      type        = "Service"
    }
    resources = [
      aws_sqs_queue.ecs_processing_queue.arn
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
    effect  = "Allow"
    actions = [
      "sqs:ReceiveMessage",
      "sqs:ChangeMessageVisibility",
      "sqs:GetQueueUrl",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes"
    ]
    resources = [
      aws_sqs_queue.ecs_processing_queue.arn
    ]
  }
}
