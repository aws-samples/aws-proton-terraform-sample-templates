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
    key    = "ecs-ec2-env.state"
  }
}

# Configure the AWS Provider
provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      environment = var.environment.name
    }
  }
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}