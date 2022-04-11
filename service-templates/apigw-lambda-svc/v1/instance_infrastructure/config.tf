terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }

  backend "s3" {
    region = "us-east-1"
    bucket = "terraform-samples-259837135622-apigw-lambda-svc"
    key = "instance.tfstate"
  }
}

# Configure the AWS Provider
provider "aws" {
  region = data.aws_region.current.id
  alias = "default"

  default_tags {
    tags = {
      "proton:service" = var.service.name
    }
  }
}
