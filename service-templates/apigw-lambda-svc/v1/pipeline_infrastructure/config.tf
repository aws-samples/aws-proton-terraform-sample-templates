terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }

  backend "s3" {}
}

#data "aws_region" "current" {}

# Configure the AWS Provider
provider "aws" {
  region = data.aws_region.current.id
  alias = "default"

  default_tags {
    tags = {
      "proton:pipeline" = var.service.name
    }
  }
}
#
#variable "aws_region" {
#  type    = string
#  default = "us-east-1"
#}