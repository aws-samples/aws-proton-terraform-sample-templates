data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

data "aws_iam_policy_document" "sns_publish_policy_document" {
  statement {
    actions = [
      "sns:Publish"
    ]
    resources = [
      var.environment.outputs.SnsTopicArn
    ]
  }
}