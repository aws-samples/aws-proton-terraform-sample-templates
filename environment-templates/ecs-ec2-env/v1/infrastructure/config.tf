terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.4.0"
    }
  }

  backend "s3" {}
}

# Configure the AWS Provider
provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      "proton:environment" = var.environment.name
    }
  }
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}