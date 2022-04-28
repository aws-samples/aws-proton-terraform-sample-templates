terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.4.0"
    }
  }

  backend "s3" {
    bucket = "racicot-arrow-testing"
    region = "us-east-1"
    key    = "scheduled-ecs-ec2-svc.state"
  }
}

# Configure the AWS Provider
provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      service = var.service.name
    }
  }
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}