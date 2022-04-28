terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }

  backend "s3" {
    region = "ap-northeast-1"
    bucket = "terraform-samples-443437525071-worker-ecs-fargate-sqs-svc"
    key    = "pipeline.tfstate"
  }
}

# Configure the AWS Provider
provider "aws" {
  region = var.aws_region
  alias  = "default"

  default_tags {
    tags = {
      "proton:pipeline" = var.service.name
    }
  }
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}
