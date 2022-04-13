terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }

  backend "s3" {
    region = "us-east-1"
    bucket = "terraform-states-858487653465"
    key    = "fargate-pipeline"
  }
}

# Configure the AWS Provider
provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      "proton:pipeline" : var.service.name
    }
  }
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}