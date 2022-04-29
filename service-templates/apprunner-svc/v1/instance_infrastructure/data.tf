data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

variable "task_size_cpu" {
  type = map(string)
  default = {
    "medium" = "1 vCPU"
    "large"  = "2 vCPU"
  }
}

variable "task_size_memory" {
  type = map(string)
  default = {
    "medium" = "2048"
    "large"  = "4096"
  }
}

data "aws_iam_policy_document" "service_access_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"

    principals {
      type        = "Service"
      identifiers = ["build.apprunner.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "publish_2_sns" {
  statement {
    actions   = ["sns:Publish"]
    effect    = "Allow"
    resources = [var.environment.outputs.SnsTopicArn]

  }
}

data "aws_iam_policy_document" "service_access_role_default_policy" {
  statement {
    actions = [
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage"
    ]
    effect    = "Allow"
    resources = ["*"]
  }
}