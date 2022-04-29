terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }

  backend "s3" {
    region = "ap-northeast-1"
    bucket = "terraform-samples-443437525071-worker-fargate-svc"
    key    = "instance.tfstate"
  }
}

# Configure the AWS Provider
provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      "proton:service" : var.service.name
    }
  }
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}