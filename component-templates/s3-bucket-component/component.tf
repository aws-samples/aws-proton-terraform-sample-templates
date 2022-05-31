terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }

  backend "s3" {}
}

# Configure the AWS Provider
provider "aws" {
  region = var.aws_region
  alias  = "default"
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

resource "aws_s3_bucket" "s3_bucket" {
  bucket_prefix = "component-bucket"
}

data "aws_iam_policy_document" "s3_bucket_policy_document" {
  statement {
    effect = "Allow"
    actions = [
      "s3:Get*",
      "s3:List*",
      "s3:PutObject"
    ]
    resources = [
      aws_s3_bucket.s3_bucket.arn
    ]
  }
}

resource "aws_iam_policy" "s3_bucket_policy" {
  policy = data.aws_iam_policy_document.s3_bucket_policy_document.json
}

output "BucketArn" {
  value = aws_s3_bucket.s3_bucket.arn
}

output "BucketAccessPolicyArn" {
  value = aws_iam_policy.s3_bucket_policy.arn
}