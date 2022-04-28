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

resource "aws_service_discovery_private_dns_namespace" "cloud_map_namespace" {
  name = "${var.environment.name}.local"
  vpc  = aws_vpc_endpoint.ec2.vpc_id
}

resource "aws_ecs_cluster" "cluster" {
  name = "ecs_cluster"
}

resource "aws_security_group" "ecs_host_security_group" {
  description = "Access to the ECS hosts that run containers"

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
    description      = "Allow all outbound traffic by default"
  }
  vpc_id = module.vpc.vpc_id
}

resource "aws_iam_instance_profile" "ec2_instance_profile" {
  role = aws_iam_role.ecs_host_instance_role.name
}

resource "aws_launch_configuration" "ec2_launch_config" {
  image_id             = data.aws_ssm_parameter.ami_id.value
  instance_type        = var.environment.inputs.InstanceType
  iam_instance_profile = aws_iam_instance_profile.ec2_instance_profile.arn
  security_groups = [
    aws_security_group.ecs_host_security_group.id
  ]
  user_data = base64encode(
    <<-EOT
  #!/bin/bash
  echo ECS_CLUSTER=${aws_ecs_cluster.cluster.name} >> /etc/ecs/ecs.config
  sudo iptables --insert FORWARD 1 --in-interface docker+ --destination 169.254.169.254/32 --jump DROP
  sudo service iptables save
  echo ECS_AWSVPC_BLOCK_IMDS=true >> /etc/ecs/ecs.config
EOT
  )
  depends_on = [
    aws_iam_policy.ecs_drain_hook_default_policy,
    aws_iam_role.ecs_host_instance_role
  ]
}

resource "aws_autoscaling_group" "ecs_autoscaling_group" {
  max_size             = var.environment.inputs.MaxSize
  min_size             = 1
  desired_capacity     = var.environment.inputs.DesiredCapacity
  launch_configuration = aws_launch_configuration.ec2_launch_config.name
  vpc_zone_identifier  = (var.environment.inputs.subnet_type == "private") ? module.vpc.private_subnets : module.vpc.public_subnets
}

resource "aws_autoscaling_lifecycle_hook" "ecs_drain_hook" {
  autoscaling_group_name  = aws_autoscaling_group.ecs_autoscaling_group.name
  lifecycle_transition    = "autoscaling:EC2_INSTANCE_TERMINATING"
  name                    = "ecs_drain_hook"
  default_result          = "CONTINUE"
  heartbeat_timeout       = 300
  notification_target_arn = aws_sns_topic.ecs_drain_hook_topic.arn
  role_arn                = aws_iam_role.ecs_drain_hook_role.arn
  depends_on = [
    aws_iam_policy.ecs_drain_hook_default_policy,
    aws_iam_role.ecs_drain_hook_role
  ]
}

resource "aws_sns_topic" "ping_topic" {
  name_prefix       = "ping-"
  kms_master_key_id = "alias/aws/sns"
}

resource "aws_sns_topic" "ecs_drain_hook_topic" {
  name_prefix = "ecs_drain_hook-"
}

resource "aws_lambda_function" "ecs_drain_function" {
  function_name = "${var.environment.name}_drain_hook_function"
  role          = aws_iam_role.ecs_drain_hook_function_service_role.arn
  filename      = data.archive_file.ecs_drain_hook_function.output_path
  handler       = "ecs_drain_hook_lambda.lambda_handler"
  runtime       = "python3.6"
  timeout       = 310

  environment {
    variables = {
      "CLUSTER" : aws_ecs_cluster.cluster.name
    }
  }

  depends_on = [
    aws_iam_policy.ecs_drain_hook_function_service_role_default_policy,
    aws_iam_role.ecs_drain_hook_function_service_role
  ]
}