resource "aws_security_group" "lb_sg" {
  count       = var.service_instance.inputs.loadbalancer_type == "application" ? 1 : 0
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
  security_group_id = aws_security_group.lb_sg[0].id
}

resource "aws_lb" "service_lb" {
  load_balancer_type = var.service_instance.inputs.loadbalancer_type
  security_groups = var.service_instance.inputs.loadbalancer_type == "application" ? [
    aws_security_group.lb_sg[0].id
  ] : null
  subnets = [var.environment.outputs.PublicSubnetOneId, var.environment.outputs.PublicSubnetTwoId]

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
    enabled = false
    type    = var.service_instance.inputs.loadbalancer_type == "application" ? "lb_cookie" : "source_ip"
  }
  target_type = "ip"
  vpc_id      = var.environment.outputs.VpcId
}

resource "aws_iam_role" "ecs_task_execution_role" {
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "ecs-tasks.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      }
    ]
  })
  permissions_boundary = aws_iam_policy.task_role_permission_boundary.arn
  managed_policy_arns  = concat([aws_iam_policy.base_task_role_policy.arn], local.component_policy_arns)
}

resource "aws_iam_policy" "task_role_permission_boundary" {
  policy = data.aws_iam_policy_document.task_role_permission_boundary_document.json
}

resource "aws_iam_policy" "base_task_role_policy" {
  policy = data.aws_iam_policy_document.base_task_role_managed_policy_document.json
}

resource "aws_iam_role_policy_attachment" "publish_role_policy_attachment" {
  policy_arn = aws_iam_policy.ecs_task_execution_role_policy.arn
  role       = aws_iam_role.ecs_task_execution_role.name
}

resource "aws_iam_policy" "ecs_task_execution_role_policy" {
  policy = data.aws_iam_policy_document.ecs_task_execution_role_policy_document.json
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

resource "aws_ecs_task_definition" "service_task_definition" {
  family                   = "${var.service.name}_${var.service_instance.name}"
  task_role_arn            = aws_iam_role.ecs_task_execution_role.arn
  execution_role_arn       = var.environment.outputs.ServiceTaskDefExecutionRoleArn
  network_mode             = "awsvpc"
  cpu                      = var.task_size_cpu[var.service_instance.inputs.task_size]
  memory                   = var.task_size_memory[var.service_instance.inputs.task_size]
  requires_compatibilities = ["FARGATE"]
  container_definitions    = <<TASK_DEFINITION
  [
      {
        "name": "${var.service_instance.name}",
        "image": "${var.service_instance.inputs.image}",
        "essential": true,
        "portMappings": [
          {
            "containerPort": ${var.service_instance.inputs.port},
            "protocol": "tcp"
          }
        ],
        "environment": ${jsonencode(local.ecs_environment_variables)}
      }
  ]
  TASK_DEFINITION
}

resource "aws_ecs_service" "service" {
  name                               = "${var.service.name}_${var.service_instance.name}"
  cluster                            = var.environment.outputs.ClusterName
  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 50
  desired_count                      = var.service_instance.inputs.desired_count
  enable_ecs_managed_tags            = false
  health_check_grace_period_seconds  = 60
  launch_type                        = "FARGATE"

  load_balancer {
    container_name   = var.service_instance.name
    container_port   = var.service_instance.inputs.port
    target_group_arn = aws_lb_target_group.service_lb_public_listener_target_group.arn
  }

  network_configuration {
    #    Assign a public IP address to the ENI
    assign_public_ip = var.service_instance.inputs.subnet_type == "private" ? false : true
    security_groups  = [aws_security_group.service_security_group.id]
    subnets = var.service_instance.inputs.subnet_type == "private" ? [
      var.environment.outputs.PrivateSubnetOneId, var.environment.outputs.PrivateSubnetTwoId
    ] : [var.environment.outputs.PublicSubnetOneId, var.environment.outputs.PublicSubnetTwoId]
  }

  task_definition = aws_ecs_task_definition.service_task_definition.arn
  depends_on = [
    aws_lb_target_group.service_lb_public_listener_target_group, aws_lb_listener.service_lb_public_listener
  ]
}

resource "aws_service_discovery_service" "service_cloud_map_service" {
  name = "${var.service.name}.${var.service_instance.name}_cloud_map_service"

  dns_config {
    namespace_id = var.environment.outputs.CloudMapNamespaceId

    dns_records {
      ttl  = 60
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

resource "aws_security_group" "service_security_group" {
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
  resource_id        = "service/${var.environment.outputs.ClusterName}/${aws_ecs_service.service.name}"
  role_arn           = "arn:aws:iam::${local.account_id}:role/aws-service-role/ecs.application-autoscaling.amazonaws.com/AWSServiceRoleForApplicationAutoScaling_ECSService"
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
  name               = "LBFargateServiceTaskCountTargetMemoryScaling"
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
