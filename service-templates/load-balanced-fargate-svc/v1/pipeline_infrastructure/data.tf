data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

data "aws_iam_policy_document" "pull_only_policy" {
  statement {
    sid    = "AllowPull"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = formatlist("arn:aws:iam::%s:root", local.environment_account_ids)
    }

    actions = [
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage"
    ]
  }
}

data "aws_iam_policy_document" "publish_role_default_policy" {
  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    effect = "Allow"
    resources = [
      "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/codebuild/${aws_codebuild_project.build_project.name}",
      "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/codebuild/${aws_codebuild_project.build_project.name}*"
    ]
  }
  statement {
    actions = [
      "codebuild:CreateReportGroup",
      "codebuild:CreateReport",
      "codebuild:UpdateReport",
      "codebuild:BatchPutTestCases"
    ]
    effect = "Allow"
    resources = [
      "arn:aws:codebuild:${local.region}:${local.account_id}:report-group:/${aws_codebuild_project.build_project.name}*",
    ]
  }
  statement {
    actions   = ["ecr:GetAuthorizationToken"]
    effect    = "Allow"
    resources = ["*"]
  }

  statement {
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:CompleteLayerUpload",
      "ecr:GetAuthorizationToken",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart"
    ]
    effect    = "Allow"
    resources = [aws_ecr_repository.ecr_repo.arn]
  }

  statement {
    actions   = ["proton:GetService"]
    effect    = "Allow"
    resources = ["*"]
  }

  statement {
    actions = [
      "s3:GetObject*",
      "s3:GetBucket*",
      "s3:List*",
      "s3:DeleteObject*",
      "s3:PutObject*",
      "s3:Abort*"
    ]
    effect = "Allow"
    resources = [
      aws_s3_bucket.pipeline_artifacts_bucket.arn,
      "${aws_s3_bucket.pipeline_artifacts_bucket.arn}*"
    ]
  }

  statement {
    actions = [
      "kms:Decrypt",
      "kms:DescribeKey",
      "kms:Encrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*"
    ]
    effect    = "Allow"
    resources = [aws_kms_key.pipeline_artifacts_bucket_encryption_key.arn]
  }
}

data "aws_iam_policy_document" "deployment_role_default_policy" {
  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    effect = "Allow"
    resources = [
      "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/codebuild/Deploy*Project*",
      "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/codebuild/Deploy*Project:*",
    ]
  }
  statement {
    actions = [
      "codebuild:CreateReportGroup",
      "codebuild:CreateReport",
      "codebuild:UpdateReport",
      "codebuild:BatchPutTestCases"
    ]
    effect = "Allow"
    resources = [
      "arn:aws:codebuild:${local.region}:${local.account_id}:report-group:/Deploy*Project-*",
    ]
  }
  statement {
    actions = [
      "proton:GetServiceInstance",
      "proton:UpdateServiceInstance"
    ]
    effect    = "Allow"
    resources = ["*"]
  }
  statement {
    actions = [
      "s3:GetObject*",
      "s3:GetBucket*",
      "s3:List*"
    ]
    effect = "Allow"
    resources = [
      aws_s3_bucket.pipeline_artifacts_bucket.arn,
      "${aws_s3_bucket.pipeline_artifacts_bucket.arn}/*"
    ]
  }
  statement {
    actions = [
      "kms:Decrypt",
      "kms:DescribeKey",
      "kms:Encrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*"
    ]
    effect    = "Allow"
    resources = [aws_kms_key.pipeline_artifacts_bucket_encryption_key.arn]
  }
}

data "aws_iam_policy_document" "pipeline_role_default_policy" {
  statement {
    actions = [
      "s3:GetObject*",
      "s3:GetBucket*",
      "s3:List*",
      "s3:DeleteObject*",
      "s3:PutObject*",
      "s3:Abort*"
    ]
    effect = "Allow"
    resources = [
      aws_s3_bucket.pipeline_artifacts_bucket.arn,
      "${aws_s3_bucket.pipeline_artifacts_bucket.arn}/*"
    ]
  }

  statement {
    actions = [
      "kms:Decrypt",
      "kms:DescribeKey",
      "kms:Encrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*"
    ]
    effect    = "Allow"
    resources = [aws_kms_key.pipeline_artifacts_bucket_encryption_key.arn]
  }

  statement {
    actions   = ["codestar-connections:*"]
    effect    = "Allow"
    resources = ["*"]
  }

  statement {
    actions   = ["sts:AssumeRole"]
    effect    = "Allow"
    resources = [aws_iam_role.pipeline_build_codepipeline_action_role.arn]
  }

  statement {
    actions   = ["sts:AssumeRole"]
    effect    = "Allow"
    resources = [aws_iam_role.pipeline_deploy_codepipeline_action_role.arn]
  }
}

data "aws_iam_policy_document" "pipeline_artifacts_bucket_key_policy" {
  statement {
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
    effect = "Allow"
    principals {
      identifiers = ["arn:aws:iam::${local.account_id}:root"]
      type        = "AWS"
    }
    resources = ["*"]
  }

  statement {
    actions = [
      "kms:Decrypt",
      "kms:DescribeKey",
      "kms:Encrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*"
    ]
    effect = "Allow"
    principals {
      identifiers = [aws_iam_role.pipeline_role.arn]
      type        = "AWS"
    }
    resources = ["*"]
  }

  statement {
    actions = [
      "kms:Decrypt",
      "kms:DescribeKey",
      "kms:Encrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*"
    ]
    effect = "Allow"
    principals {
      identifiers = [aws_iam_role.publish_role.arn]
      type        = "AWS"
    }
    resources = ["*"]
  }

  statement {
    actions = [
      "kms:Decrypt",
      "kms:Encrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*"
    ]
    effect    = "Allow"
    resources = ["*"]
    principals {
      identifiers = [aws_iam_role.deployment_role.arn]
      type        = "AWS"
    }
  }

  statement {
    actions = [
      "kms:Decrypt",
      "kms:DescribeKey",
      "kms:Encrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*"
    ]
    effect    = "Allow"
    resources = ["*"]
    principals {
      identifiers = [aws_iam_role.deployment_role.arn]
      type        = "AWS"
    }
  }
}

data "aws_iam_policy_document" "pipeline_build_codepipeline_action_role_policy" {
  statement {
    actions = [
      "codebuild:BatchGetBuilds",
      "codebuild:StartBuild",
      "codebuild:StopBuild"
    ]
    effect    = "Allow"
    resources = [aws_codebuild_project.build_project.arn]
  }
}

data "aws_iam_policy_document" "pipeline_deploy_codepipeline_action_role_policy" {
  statement {
    actions = [
      "codebuild:BatchGetBuilds",
      "codebuild:StartBuild",
      "codebuild:StopBuild"
    ]
    effect    = "Allow"
    resources = ["arn:aws:codebuild:${local.region}:${local.account_id}:project/Deploy*", ]
  }
}