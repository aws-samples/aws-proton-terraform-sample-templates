resource "aws_s3_bucket" "function_bucket" {
  bucket = "function_bucket"
  #  server_side_encryption_configuration {
  #    rule {
  #      apply_server_side_encryption_by_default {
  #        sse_algorithm = "AES256"
  #      }
  #    }
  #  }
}

data "aws_iam_policy_document" "management_account_access" {
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

resource "aws_s3_bucket_policy" "management_account_access" {
  policy = data.aws_iam_policy_document.management_account_access.json
  bucket = aws_s3_bucket.function_bucket.id
}

#resource "aws_s3_bucket_acl" "example" {
#  bucket = aws_s3_bucket.example.id
#  acl    = "private"
#}
#
#resource "aws_iam_role" "example" {
#  name = "example"
#
#  assume_role_policy = <<EOF
#{
#  "Version": "2012-10-17",
#  "Statement": [
#    {
#      "Effect": "Allow",
#      "Principal": {
#        "Service": "codebuild.amazonaws.com"
#      },
#      "Action": "sts:AssumeRole"
#    }
#  ]
#}
#EOF
#}

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

#resource "aws_codebuild_project" "example" {
#    name          = "test-project"
#    description   = "test_codebuild_project"
#    build_timeout = "5"
#    service_role  = aws_iam_role.example.arn
#
#  artifacts {
#    type = "CODEPIPELINE"
#  }
#
#  #  cache {
#  #    type     = "S3"
#  #    location = aws_s3_bucket.example.bucket
#  #  }
#
#  environment {
#    compute_type                = "BUILD_GENERAL1_SMALL"
#    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:3.0"
#    type                        = "LINUX_CONTAINER"
#    image_pull_credentials_type = "CODEBUILD"
#
#    environment_variable {
#      name  = "bucket_name"
#      value = "function_bucket"
#    }
#
#    environment_variable {
#      name  = "service_name"
#      value = var.service.name
#    }
#  }
#
#  logs_config {
#    cloudwatch_logs {
#      group_name  = "log-group"
#      stream_name = "log-stream"
#    }
#
#    s3_logs {
#      status   = "ENABLED"
#      location = "${aws_s3_bucket.example.id}/build-log"
#    }
#  }
#
#  source {
#    type            = "GITHUB"
#    location        = "https://github.com/mitchellh/packer.git"
#    git_clone_depth = 1
#
#    git_submodules_config {
#      fetch_submodules = true
#    }
#  }
#
#  source_version = "master"
#
#  vpc_config {
#    vpc_id = aws_vpc.example.id
#
#    subnets = [
#      aws_subnet.example1.id,
#      aws_subnet.example2.id,
#    ]
#
#    security_group_ids = [
#      aws_security_group.example1.id,
#      aws_security_group.example2.id,
#    ]
#  }
#
#  tags = {
#    Environment = "Test"
#  }
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