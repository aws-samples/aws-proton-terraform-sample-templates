resource "aws_security_group" "lb_sg" {
  count       = var.service_instance.inputs.loadbalancer_type == "application" ? 1 : 0
  name        = "service_lb_security_group"
  description = "Automatically created Security Group for Application LB."
  vpc_id      = var.environment.outputs.VpcId

  ingress {
    description = "Allow from anyone on port 80"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group_rule" "lb_sg_egress" {
  count             = var.service_instance.inputs.loadbalancer_type == "application" ? 1 : 0
  description       = "Load balancer to target"
  type              = "egress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.service_security_group.id
}

resource "aws_lb" "service_lb" {
  name               = "${var.service.name}-lb"
  load_balancer_type = var.service_instance.inputs.loadbalancer_type
  security_groups    = var.service_instance.inputs.loadbalancer_type == "application" ? [aws_security_group.lb_sg[0].id] : null
  subnets            = [var.environment.outputs.PublicSubnet1, var.environment.outputs.PublicSubnet2]

  enable_deletion_protection = false
}

resource "aws_lb_listener" "service_lb_public_listener" {
  load_balancer_arn = aws_lb.service_lb.arn
  port              = 80
  protocol          = var.service_instance.inputs.loadbalancer_type == "application" ? "HTTP" : "TCP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.service_lb_public_listener_target_group.arn
  }
}

resource "aws_lb_target_group" "service_lb_public_listener_target_group" {
  port     = var.service_instance.inputs.port
  protocol = var.service_instance.inputs.loadbalancer_type == "application" ? "HTTP" : "TCP"

  stickiness {
    enabled = var.service_instance.inputs.loadbalancer_type == "application" ? false : null
    type    = "lb_cookie"
  }
  target_type = "instance"
  vpc_id      = var.environment.outputs.VpcId
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name_prefix        = "service_task_definition_execution_role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_execution_assume_role_policy.json
}

resource "aws_iam_policy" "ecs_task_execution_role_policy" {
  name   = "publish_2_sns"
  policy = data.aws_iam_policy_document.ecs_task_execution_role_policy.json
}

resource "aws_iam_role_policy_attachment" "publish_role_policy_attachment" {
  policy_arn = aws_iam_policy.ecs_task_execution_role_policy.arn
  role       = aws_iam_role.ecs_task_execution_role.name
}

variable "task_sizes" {
  default = {
    x-small = { cpu = 256, memory = 512 }
    small   = { cpu = 512, memory = 1024 }
    medium  = { cpu = 1024, memory = 2048 }
    large   = { cpu = 2048, memory = 4096 }
    x-large = { cpu = 4096, memory = 8192 }
  }
}

resource "aws_cloudwatch_log_group" "ecs_log_group" {

}

resource "aws_ecs_task_definition" "service_task_definition" {
  family                   = "${var.service.name}_${var.service_instance.name}"
  task_role_arn            = aws_iam_role.ecs_task_execution_role.arn
  execution_role_arn       = var.environment.outputs.ServiceTaskDefExecutionRole
  network_mode             = "bridge"
  cpu                      = lookup(var.task_sizes[var.service_instance.inputs.task_size], "cpu")
  memory                   = lookup(var.task_sizes[var.service_instance.inputs.task_size], "memory")
  requires_compatibilities = ["EC2"]
  container_definitions = jsonencode([
    {
      portMappings = [
        {
          containerPort = "${var.service_instance.inputs.port}"
          hostPort      = 0
          protocol      = "tcp"
        }
      ]
      environment = [
        { name = "sns_topic_arn", value = "{ping:${var.environment.outputs.SnsTopic}" },
        { name = "sns_region", value = var.environment.outputs.SnsRegion },
        { name = "backend_url", value = var.service_instance.inputs.backendurl }
      ],
      essential = true,
      image     = var.service_instance.inputs.image,
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          awslogs-group : aws_cloudwatch_log_group.ecs_log_group.name,
          awslogs-region : var.aws_region,
          awslogs-stream-prefix : "${var.service.name}/${var.service_instance.name}"
        }
      }
      name   = var.service_instance.name,
      cpu    = lookup(var.task_sizes[var.service_instance.inputs.task_size], "cpu")
      memory = lookup(var.task_sizes[var.service_instance.inputs.task_size], "memory")
    }
  ])
}


resource "aws_service_discovery_service" "service_cloud_map_service" {
  name = "${var.service.name}.${var.service_instance.name}_cloud_map_service"

  dns_config {
    namespace_id = var.environment.outputs.CloudMapNamespaceId

    dns_records {
      ttl  = 60
      type = "SRV"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

resource "aws_ecs_service" "service" {
  name                               = "${var.service.name}_${var.service_instance.name}"
  cluster                            = var.environment.outputs.Cluster
  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 50
  desired_count                      = var.service_instance.inputs.desired_count
  enable_ecs_managed_tags            = false
  health_check_grace_period_seconds  = 60
  launch_type                        = "EC2"
  scheduling_strategy                = "REPLICA"

  load_balancer {
    container_name   = var.service_instance.name
    container_port   = var.service_instance.inputs.port
    target_group_arn = aws_lb_target_group.service_lb_public_listener_target_group.arn
  }

  service_registries {
    container_name = var.service_instance.name
    container_port = var.service_instance.inputs.port
    registry_arn   = aws_service_discovery_service.service_cloud_map_service.arn
  }

  task_definition = aws_ecs_task_definition.service_task_definition.arn
  depends_on      = [aws_lb_target_group.service_lb_public_listener_target_group, aws_lb_listener.service_lb_public_listener]
}

resource "aws_security_group" "service_security_group" {
  name        = "service_security_group"
  description = "Automatically created Security Group for the Service"
  vpc_id      = var.environment.outputs.VpcId

  egress {
    description = "Allow all outbound traffic by default"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group_rule" "service_ingress" {
  description = "Load balancer to target"
  type        = "ingress"
  from_port   = 80
  to_port     = 80
  protocol    = "tcp"
  #Network Load Balancers do not have associated security groups. See - https://docs.aws.amazon.com/elasticloadbalancing/latest/network/target-group-register-targets.html#target-security-groups
  security_group_id = var.service_instance.inputs.loadbalancer_type == "application" ? aws_security_group.service_security_group.id : null
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_appautoscaling_target" "service_task_count_target" {
  max_capacity       = 10
  min_capacity       = 1
  resource_id        = "service/${var.environment.outputs.Cluster}/${aws_ecs_service.service.name}"
  role_arn           = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/ecs.application-autoscaling.amazonaws.com/AWSServiceRoleForApplicationAutoScaling_ECSService"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "service_task_count_target_cpu_scaling" {
  name               = "LBFargateServiceTaskCountTargetCpuScaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.service_task_count_target.resource_id
  scalable_dimension = aws_appautoscaling_target.service_task_count_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.service_task_count_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = 50
  }
}

resource "aws_appautoscaling_policy" "service_task_count_target_memory_scaling" {
  name               = "LBECSEC2ServiceTaskCountTargetMemoryScaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.service_task_count_target.resource_id
  scalable_dimension = aws_appautoscaling_target.service_task_count_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.service_task_count_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value = 50
  }
}
