terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.4.0"
    }
  }

  backend "s3" {
    bucket = "aws-proton-terraform-bucket-074207182078"
    region = "ap-northeast-1"
    key    = "ecs-ec2-env/terraform.tfstate"
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
  default = "ap-northeast-1"
}