module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  cidr = var.environment.inputs.vpc_cidr

  azs = [data.aws_availability_zones.available.names[0], data.aws_availability_zones.available.names[1]]
  private_subnets = [
    var.environment.inputs.private_subnet_one_cidr,
    var.environment.inputs.private_subnet_two_cidr
  ]
  public_subnets       = [var.environment.inputs.public_subnet_one_cidr, var.environment.inputs.public_subnet_two_cidr]
  enable_nat_gateway   = true
  enable_vpn_gateway   = true
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Terraform   = "true"
    Environment = var.environment.name
  }
}

resource "aws_vpc_endpoint" "ec2" {
  service_name        = "com.amazonaws.${local.region}.sns"
  vpc_id              = module.vpc.vpc_id
  private_dns_enabled = true
  vpc_endpoint_type   = "Interface"
  security_group_ids  = [module.vpc.default_security_group_id]
  subnet_ids          = module.vpc.public_subnets
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