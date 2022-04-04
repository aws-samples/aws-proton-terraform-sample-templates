module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  cidr = var.environment.inputs.vpc_cidr

  azs                = ["${var.aws_region}a"]
  private_subnets    = [var.environment.inputs.private_subnet_one_cidr, var.environment.inputs.private_subnet_two_cidr]
  public_subnets     = [var.environment.inputs.public_subnet_one_cidr, var.environment.inputs.public_subnet_two_cidr]
  enable_nat_gateway = true
  enable_vpn_gateway = true

  tags = {
    Terraform   = "true"
    Environment = var.environment.name
  }
}

resource "aws_apprunner_vpc_connector" "connector" {
  vpc_connector_name = "${var.environment.name}-vpc-connector"
  subnets            = module.vpc.public_subnets
  security_groups    = [module.vpc.default_security_group_id]
}

resource "aws_sns_topic" "ping_topic" {
  name_prefix       = "ping-"
  kms_master_key_id = "alias/aws/sns"
}