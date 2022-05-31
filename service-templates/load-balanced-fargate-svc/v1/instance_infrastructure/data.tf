data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

data "aws_iam_policy_document" "ecs_task_execution_role_policy_document" {
  statement {
    actions   = ["sns:Publish"]
    resources = [var.environment.outputs.SnsTopicArn]
  }
}

data "aws_iam_policy_document" "task_role_permission_boundary_document" {
  statement {
    effect = "Allow"
    actions = [
      "s3:Get*",
      "s3:List*",
      "s3:PutObject",
      "sqs:Get*",
      "sqs:List*",
      "sqs:Send*"
    ]
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "base_task_role_managed_policy_document" {
  statement {
    effect = "Allow"
    actions = [
      "cloudwatch:PutMetricData",
      "logs:PutLogEvents"
    ]
    resources = ["*"]
  }
}