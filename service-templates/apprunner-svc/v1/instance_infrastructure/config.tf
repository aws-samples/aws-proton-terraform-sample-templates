terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }

  backend "s3" {
    region = "us-east-1"
    bucket = "terraform-states-858487653465"
    key    = "instance.tfstate"
  }
}

# Configure the AWS Provider
provider "aws" {
  region = data.aws_region.current.id
  alias  = "default"

  default_tags {
    tags = {
      "proton:service" = var.service.name
    }
  }
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}