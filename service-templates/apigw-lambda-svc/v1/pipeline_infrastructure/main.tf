locals {
  account_id = data.aws_caller_identity.current.account_id
}

resource "aws_s3_bucket" "function_bucket" {
  bucket = "function_bucket"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "aes256" {
  bucket = aws_s3_bucket.function_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

data "aws_iam_policy_document" "function_bucket_policy_document" {
  statement {
    principals {
      type        = "AWS"
      identifiers = [for id in split(",", var.pipeline.inputs.environment_account_ids) : "arn:aws:iam::${id}:root"]
    }
    actions = [
      "s3:GetObject"
    ]
    resources = [
      aws_s3_bucket.function_bucket.arn,
      "${aws_s3_bucket.function_bucket.arn}/*"
    ]
  }
}

resource "aws_s3_bucket_policy" "function_bucket_policy" {
  policy = data.aws_iam_policy_document.function_bucket_policy_document.json
  bucket = aws_s3_bucket.function_bucket.id
}

resource "aws_codebuild_project" "build_project" {
  name         = "build_project"
  #    description   = ""
  #    build_timeout = "5"
  service_role = aws_iam_role.publish_role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  #  cache {
  #    type     = "S3"
  #    location = aws_s3_bucket.example.bucket
  #  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:3.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"

    environment_variable {
      name  = "bucket_name"
      value = "function_bucket"
    }

    environment_variable {
      name  = "service_name"
      value = var.service.name
    }
  }

  source {
    buildspec = <<EOF
                {
                  "version": "0.2",
                  "phases": {
                    "install": {
                      "runtime-versions": {{
                          {"ruby2.7": {"ruby": "2.7"},
                            "go1.x": {"golang": "1.x"},
                            "nodejs12.x": {"nodejs": "12.x"},
                            "python3.8": {"python": "3.8"},
                            "java11": {"java": "openjdk11.x"},
                            "dotnetcore3.1": {"dotnet": "3.1"}
                          }[service_instances[0].outputs.LambdaRuntime] | tojson | safe }},
                      "commands": [
                        "pip3 install --upgrade --user awscli",
                        "echo 'f6bd1536a743ab170b35c94ed4c7c4479763356bd543af5d391122f4af852460  yq_linux_amd64' > yq_linux_amd64.sha",
                        "wget https://github.com/mikefarah/yq/releases/download/3.4.0/yq_linux_amd64",
                        "sha256sum -c yq_linux_amd64.sha",
                        "mv yq_linux_amd64 /usr/bin/yq",
                        "chmod +x /usr/bin/yq"
                      ]
                    },
                    "pre_build": {
                      "commands": [
                        "cd $CODEBUILD_SRC_DIR/{{pipeline.inputs.code_dir}}",
                        "{{ pipeline.inputs.unit_test_command }}"
                      ]
                    },
                    "build": {
                      "commands": [
                        "{{ pipeline.inputs.packaging_command }}",
                        "FUNCTION_URI=s3://$bucket_name/$CODEBUILD_BUILD_NUMBER/function.zip",
                        "aws s3 cp function.zip $FUNCTION_URI"
                      ]
                    },
                    "post_build": {
                      "commands": [
                        "aws proton --region $AWS_DEFAULT_REGION get-service --name $service_name | jq -r .service.spec > service.yaml",
                        "yq w service.yaml 'instances[*].spec.code_uri' \"$FUNCTION_URI\" > rendered_service.yaml"
                      ]
                    }
                  },
                  "artifacts": {
                    "files": [
                      "{{pipeline.inputs.code_dir}}/rendered_service.yaml"
                    ]
                  }
                }
EOF

    type = "CODEPIPELINE"
  }

  encryption_key = aws_kms_key.pipeline_artifacts_bucket_key.arn
}


resource "aws_codebuild_project" "deploy_projects" {
  for_each = toset(var.service_instances)

  name         = "deploy_project_${each.value.name}}"
  service_role = aws_iam_role.publish_role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:3.0"
    type                        = "LINUX_CONTAINER"
    privileged_mode             = false
    image_pull_credentials_type = "CODEBUILD"

    environment_variable {
      name  = "service_instance_name"
      value = each.value.name
    }

    environment_variable {
      name  = "service_name"
      value = var.service.name
    }
  }

  source {
    type = "CODEPIPELINE"
    buildspec = <<EOF
          {
            "version": "0.2",
            "phases": {
              "build": {
                "commands": [
                  "pip3 install --upgrade --user awscli",
                  "aws proton --region $AWS_DEFAULT_REGION update-service-instance --deployment-type CURRENT_VERSION --name $service_instance_name --service-name $service_name --spec file://{{pipeline.inputs.code_dir}}/rendered_service.yaml",
                  "aws proton --region $AWS_DEFAULT_REGION wait service-instance-deployed --name $service_instance_name --service-name $service_name"
                ]
              }
            }
          }
EOF
  }

  encryption_key = aws_kms_key.pipeline_artifacts_bucket_key.arn
}

resource "aws_iam_role" "publish_role" {
  name = "publish_role"

  #todo: rewrite policy in HCL constructs
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codebuild.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

data "aws_iam_policy_document" "publish_role_policy" {
  statement {
    effect    = "Allow"
    resources = [
      "arn:aws:logs:${data.aws_region}:${account_id}:log-group:/aws/codebuild/${aws_codebuild_project.build_project.id}",
      "arn:aws:logs:${data.aws_region}:${account_id}:log-group:/aws/codebuild/${aws_codebuild_project.build_project.id}*"
    ]
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
  }
  statement {
    effect    = "Allow"
    resources = [
      "arn:aws:codebuild:${data.aws_region}:${account_id}:report-group:/${aws_codebuild_project.build_project.id}*",
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
    actions   = ["proton:GetService"]
  }
  statement {
    effect    = "Allow"
    resources = [
      aws_s3_bucket.function_bucket.arn,
      "${aws_s3_bucket.function_bucket.arn}/*"
    ]
    actions = [
      "s3:GetObject*",
      "s3:GetBucket*",
      "s3:List*",
      "s3:DeleteObject*",
      "s3:PutObject*",
      "s3:Abort*",
      "s3:CreateMultipartUpload"
    ]
  }
  statement {
    effect    = "Allow"
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
}

resource "aws_iam_role_policy_attachment" "publish_role_policy_attachment" {
  policy_arn = data.aws_iam_policy_document.publish_role_policy
  role       = aws_iam_role.publish_role.name
}

resource "aws_iam_role" "deployment_role" {
  name = "deployment_role"

  #todo: rewrite policy in HCL constructs
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codebuild.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

data "aws_iam_policy_document" "deployment_role_policy" {
  statement {
    effect    = "Allow"
    resources = [
      "arn:aws:logs:${data.aws_region}:${account_id}:log-group:/aws/codebuild/Deploy/Project*",
      "arn:aws:logs:${data.aws_region}:${account_id}:log-group:/aws/codebuild/Deploy/Project:*",
    ]
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
  }
  statement {
    effect    = "Allow"
    resources = [
      "arn:aws:codebuild:${data.aws_region}:${account_id}:report-group:/Deploy*Project-*",
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
    actions   = [
      "proton:GetServiceInstance",
      "proton:UpdateServiceInstance"
    ]
  }
  statement {
    effect    = "Allow"
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
    actions   = [
      "kms:Decrypt",
      "kms:DescribeKey",
      "kms:Encrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*"
    ]
  }
}

resource "aws_iam_role_policy_attachment" "deployment_role_policy_attachment" {
  policy_arn = data.aws_iam_policy_document.deployment_role_policy
  role       = aws_iam_role.deployment_role.name
}

data "aws_iam_policy_document" "pipeline_artifacts_bucket_key_policy" {
  statement {
    effect    = "Allow"
    resources = ["*"]
    principals {
      identifiers = ["arn:aws:iam::${account}:root"]
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
  #  statement {
  #    effect    = "Allow"
  #    resources = ["*"]
  #    principals {
  #      identifiers = [aws_iam_role.publish_role.arn]
  #      type        = "AWS"
  #    }
  #    actions = [
  #      "kms:Decrypt",
  #      "kms:Encrypt",
  #      "kms:ReEncrypt*",
  #      "kms:GenerateDataKey*"
  #    ]
  #  }
  #  statement {
  #    effect    = "Allow"
  #    resources = ["*"]
  #    principals {
  #      #todo -
  #      identifiers = [aws_iam_role.deployment_role.arn]
  #      type        = "AWS"
  #    }
  #    actions = [
  #      "kms:Decrypt",
  #      "kms:DescribeKey"
  #    ]
  #  }
  statement {
    effect    = "Allow"
    resources = ["*"]
    principals {
      #todo -
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

resource "aws_s3_bucket" "pipeline_artifacts_bucket" {
  bucket = "pipeline_artifacts_bucket"
}

resource "aws_s3_bucket_public_access_block" "pipeline_artifacts_bucket_access_block" {
  bucket                  = aws_s3_bucket.pipeline_artifacts_bucket
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "pipeline_artifacts_bucket_encryption" {
  bucket = aws_s3_bucket.pipeline_artifacts_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.pipeline_artifacts_bucket_key.arn
    }
  }
}

resource "aws_kms_key" "pipeline_artifacts_bucket_key" {
  policy = data.aws_iam_policy_document.pipeline_artifacts_bucket_key_policy
}

resource "aws_kms_alias" "pipeline_artifacts_bucket_key_alias" {
  target_key_id = aws_kms_key.pipeline_artifacts_bucket_key.id
  name          = "alias/codepipeline-encryption-key-${var.service.name}"
}

resource "aws_iam_role" "pipeline_role" {
  name = "pipeline_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codebuild.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

data "aws_iam_policy_document" "pipeline_role_policy" {
  statement {
    effect    = "Allow"
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
    actions   = [
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
    actions   = [
      "codestar-connections:*"
    ]
  }
  statement {
    effect    = "Allow"
    # todo -
    resources = [PipelineBuildCodePipelineActionRole]
    actions   = [
      "sts:AssumeRole"
    ]
  }
  statement {
    effect    = "Allow"
    # todo -
    resources = [PipelineDeployCodePipelineActionRole]
    actions   = [
      "sts:AssumeRole"
    ]
  }
}

resource "aws_iam_role_policy_attachment" "pipeline_role_policy_attachment" {
  policy_arn = data.aws_iam_policy_document.pipeline_role_policy
  role       = aws_iam_role.pipeline_role
}

# todo: pipeline

#resource "aws_iam_role_policy" "example" {
#  role = aws_iam_role.example.name
#
#  policy = <<POLICY
#{
#  "Version": "2012-10-17",
#  "Statement": [
#    {
#      "Effect": "Allow",
#      "Resource": [
#        "*"
#      ],
#      "Action": [
#        "logs:CreateLogGroup",
#        "logs:CreateLogStream",
#        "logs:PutLogEvents"
#      ]
#    },
#    {
#      "Effect": "Allow",
#      "Action": [
#        "ec2:CreateNetworkInterface",
#        "ec2:DescribeDhcpOptions",
#        "ec2:DescribeNetworkInterfaces",
#        "ec2:DeleteNetworkInterface",
#        "ec2:DescribeSubnets",
#        "ec2:DescribeSecurityGroups",
#        "ec2:DescribeVpcs"
#      ],
#      "Resource": "*"
#    },
#    {
#      "Effect": "Allow",
#      "Action": [
#        "ec2:CreateNetworkInterfacePermission"
#      ],
#      "Resource": [
#        "arn:aws:ec2:us-east-1:123456789012:network-interface/*"
#      ],
#      "Condition": {
#        "StringEquals": {
#          "ec2:Subnet": [
#            "${aws_subnet.example1.arn}",
#            "${aws_subnet.example2.arn}"
#          ],
#          "ec2:AuthorizedService": "codebuild.amazonaws.com"
#        }
#      }
#    },
#    {
#      "Effect": "Allow",
#      "Action": [
#        "s3:*"
#      ],
#      "Resource": [
#        "${aws_s3_bucket.example.arn}",
#        "${aws_s3_bucket.example.arn}/*"
#      ]
#    }
#  ]
#}
#POLICY
#}

#data "aws_iam_policy_document" "pipeline_artifacts_bucket_key_policy" {
#  statement {
#    actions = [
#      "kms:Create*",
#      "kms:Describe*",
#      "kms:Enable*",
#      "kms:List*",
#      "kms:Put*",
#      "kms:Update*",
#      "kms:Revoke*",
#      "kms:Disable*",
#      "kms:Get*",
#      "kms:Delete*",
#      "kms:ScheduleKeyDeletion",
#      "kms:CancelKeyDeletion",
#      "kms:GenerateDataKey",
#      "kms:TagResource",
#      "kms:UntagResource"
#    ]
#    resources = ["*"]
#    principals {
#      type        = "AWS"
#      identifiers = ["arn:aws:iam::${local.account_id}:root"]
#    }
#  }
#
#  statement {
#    actions = [
#      "kms:Decrypt",
#      "kms:DescribeKey",
#      "kms:Encrypt",
#      "kms:ReEncrypt*",
#      "kms:GenerateDataKey*"
#    ]
#    resources = ["*"]
#    principals {
#      type        = "AWS"
#      identifiers = [aws]
#    }
#  }
#
#}

#
#resource "aws_codebuild_project" "project-with-cache" {
#  name           = "test-project-cache"
#  description    = "test_codebuild_project_cache"
#  build_timeout  = "5"
#  queued_timeout = "5"
#
#  service_role = aws_iam_role.example.arn
#
#  artifacts {
#    type = "NO_ARTIFACTS"
#  }
#
#  cache {
#    type  = "LOCAL"
#    modes = ["LOCAL_DOCKER_LAYER_CACHE", "LOCAL_SOURCE_CACHE"]
#  }
#
#  environment {
#    compute_type                = "BUILD_GENERAL1_SMALL"
#    image                       = "aws/codebuild/standard:1.0"
#    type                        = "LINUX_CONTAINER"
#    image_pull_credentials_type = "CODEBUILD"
#
#    environment_variable {
#      name  = "SOME_KEY1"
#      value = "SOME_VALUE1"
#    }
#  }
#
#  source {
#    type            = "GITHUB"
#    location        = "https://github.com/mitchellh/packer.git"
#    git_clone_depth = 1
#  }
#
#  tags = {
#    Environment = "Test"
#  }
#}