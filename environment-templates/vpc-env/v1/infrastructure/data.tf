data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_sns_topic_policy" "default" {
  arn = aws_sns_topic.ping_topic.arn

  policy = data.aws_iam_policy_document.ping_topic_policy.json
}

data "aws_iam_policy_document" "ping_topic_policy" {
  statement {
    effect = "Allow"

    actions = ["sns:Subscribe"]

    condition {
      test     = "StringEquals"
      variable = "sns:Protocol"
      values   = ["sqs"]
    }

    principals {
      identifiers = ["arn:${local.partition}:iam::${local.account_id}:root"]
      type        = "AWS"
    }

    resources = [aws_sns_topic.ping_topic.arn]
  }
}