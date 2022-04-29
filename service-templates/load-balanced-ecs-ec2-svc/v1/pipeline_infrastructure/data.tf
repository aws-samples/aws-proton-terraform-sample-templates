data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

data "aws_iam_policy_document" "publish_role_policy_document" {
  statement {
    effect = "Allow"
    resources = [
      "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/codebuild/${aws_codebuild_project.build_project.name}",
      "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/codebuild/${aws_codebuild_project.build_project.name}*"
    ]
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
  }
  statement {
    effect = "Allow"
    resources = [
      "arn:aws:codebuild:${local.region}:${local.account_id}:report-group:/${aws_codebuild_project.build_project.name}*",
    ]
    actions = [
      "codebuild:CreateReportGroup",
      "codebuild:CreateReport",
      "codebuild:UpdateReport",
      "codebuild:BatchPutTestCases"
    ]
  }
  statement {
    effect    = "Allow"
    resources = ["*"]
    actions   = ["ecr:GetAuthorizationToken"]
  }
  statement {
    effect = "Allow"
    resources = [
      aws_ecr_repository.ecr_repo.arn
    ]
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:CompleteLayerUpload",
      "ecr:GetAuthorizationToken",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart"
    ]
  }
  statement {
    effect    = "Allow"
    resources = ["*"]
    actions   = ["proton:GetService"]
  }
  statement {
    effect = "Allow"
    resources = [
      aws_s3_bucket.pipeline_artifacts_bucket.arn,
      "${aws_s3_bucket.pipeline_artifacts_bucket.arn}*"
    ]
    actions = [
      "s3:GetObject*",
      "s3:GetBucket*",
      "s3:List*",
      "s3:DeleteObject*",
      "s3:PutObject*",
      "s3:Abort*"
    ]
  }
  statement {
    effect    = "Allow"
    resources = [aws_kms_key.pipeline_artifacts_bucket_key.arn]
    actions = [
      "kms:Decrypt",
      "kms:DescribeKey",
      "kms:Encrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*"
    ]
  }
}

data "aws_iam_policy_document" "deployment_role_policy" {
  statement {
    effect = "Allow"
    resources = [
      "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/codebuild/deploy-*",
      "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/codebuild/deploy-:*",
    ]
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
  }
  statement {
    effect = "Allow"
    resources = [
      "arn:aws:codebuild:${local.region}:${local.account_id}:report-group:/deploy--*",
    ]
    actions = [
      "codebuild:CreateReportGroup",
      "codebuild:CreateReport",
      "codebuild:UpdateReport",
      "codebuild:BatchPutTestCases"
    ]
  }
  statement {
    effect    = "Allow"
    resources = ["*"]
    actions = [
      "proton:GetServiceInstance",
      "proton:UpdateServiceInstance"
    ]
  }
  statement {
    effect = "Allow"
    resources = [
      aws_s3_bucket.pipeline_artifacts_bucket.arn,
      "${aws_s3_bucket.pipeline_artifacts_bucket.arn}/*"
    ]
    actions = [
      "s3:GetObject*",
      "s3:GetBucket*",
      "s3:List*"
    ]
  }
  statement {
    effect    = "Allow"
    resources = [aws_kms_key.pipeline_artifacts_bucket_key.arn]
    actions = [
      "kms:Decrypt",
      "kms:DescribeKey",
      "kms:Encrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*"
    ]
  }
}

data "aws_iam_policy_document" "pipeline_artifacts_bucket_key_policy" {
  statement {
    effect    = "Allow"
    resources = ["*"]
    principals {
      identifiers = ["arn:aws:iam::${local.account_id}:root"]
      type        = "AWS"
    }
    actions = [
      "kms:Create*",
      "kms:Describe*",
      "kms:Enable*",
      "kms:List*",
      "kms:Put*",
      "kms:Update*",
      "kms:Revoke*",
      "kms:Disable*",
      "kms:Get*",
      "kms:Delete*",
      "kms:ScheduleKeyDeletion",
      "kms:CancelKeyDeletion",
      "kms:GenerateDataKey",
      "kms:TagResource",
      "kms:UntagResource"
    ]
  }

  statement {
    effect    = "Allow"
    resources = ["*"]
    principals {
      identifiers = [aws_iam_role.pipeline_role.arn]
      type        = "AWS"
    }
    actions = [
      "kms:Decrypt",
      "kms:DescribeKey",
      "kms:Encrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*"
    ]
  }

  statement {
    effect    = "Allow"
    resources = ["*"]
    principals {
      identifiers = [aws_iam_role.publish_role.arn]
      type        = "AWS"
    }
    actions = [
      "kms:Decrypt",
      "kms:DescribeKey",
      "kms:Encrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*"
    ]
  }

  statement {
    effect    = "Allow"
    resources = ["*"]
    principals {
      identifiers = [aws_iam_role.deployment_role.arn]
      type        = "AWS"
    }
    actions = [
      "kms:DescribeKey",
      "kms:Decrypt",
      "kms:Encrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*"
    ]
  }
}

data "aws_iam_policy_document" "pipeline_role_policy" {
  statement {
    effect = "Allow"
    resources = [
      aws_s3_bucket.pipeline_artifacts_bucket.arn,
      "${aws_s3_bucket.pipeline_artifacts_bucket.arn}*"
    ]
    actions = [
      "s3:GetObject*",
      "s3:GetBucket*",
      "s3:List*",
      "s3:DeleteObject*",
      "s3:PutObject*",
      "s3:Abort*"
    ]
  }

  statement {
    effect    = "Allow"
    resources = [aws_kms_key.pipeline_artifacts_bucket_key.arn]
    actions = [
      "kms:Decrypt",
      "kms:DescribeKey",
      "kms:Encrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*"
    ]
  }

  statement {
    effect    = "Allow"
    resources = ["*"]
    actions = [
      "codestar-connections:*"
    ]
  }

  statement {
    effect    = "Allow"
    resources = [aws_iam_role.pipeline_build_codepipeline_action_role.arn]
    actions = [
      "sts:AssumeRole"
    ]
  }

  statement {
    effect    = "Allow"
    resources = [aws_iam_role.pipeline_deploy_codepipeline_action_role.arn]
    actions = [
      "sts:AssumeRole"
    ]
  }
}

data "aws_iam_policy_document" "pipeline_build_codepipeline_action_role_policy" {
  statement {
    effect    = "Allow"
    resources = [aws_codebuild_project.build_project.arn]
    actions = [
      "codebuild:BatchGetBuilds",
      "codebuild:StartBuild",
      "codebuild:StopBuild"
    ]
  }
}

data "aws_iam_policy_document" "pipeline_deploy_codepipeline_action_role_policy" {
  statement {
    effect    = "Allow"
    resources = ["arn:aws:codebuild:${local.region}:${local.account_id}:project/deploy-*", ]
    actions = [
      "codebuild:BatchGetBuilds",
      "codebuild:StartBuild",
      "codebuild:StopBuild"
    ]
  }
}
