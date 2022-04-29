resource "aws_iam_role" "service_task_def_role" {
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
}

resource "aws_iam_role_policy_attachment" "ssn_publish_policy" {
  role       = aws_iam_role.service_task_def_role.name
  policy_arn = aws_iam_policy.sns_publish_policy.arn
}

resource "aws_iam_policy" "sns_publish_policy" {
  policy = data.aws_iam_policy_document.sns_publish_policy_document.json
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

resource "aws_ecs_task_definition" "service_task_def" {
  container_definitions = jsonencode([
    {
      essential = true,
      image     = var.service_instance.inputs.image,
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          awslogs-group : aws_cloudwatch_log_group.service_log_group.name,
          awslogs-region : var.aws_region,
          awslogs-stream-prefix : "${var.service.name}/${var.service_instance.name}"
        }
      },
      name = var.service_instance.name,
      portMappings = [
        {
          containerPort = tonumber(var.service_instance.inputs.port)
          protocol      = "tcp"
        }
      ],
      environment = [
        { name = "SNS_TOPIC_ARN", value = "{'ping':'${var.environment.outputs.SnsTopicArn}'}" },
        { name = "SNS_REGION", value = var.aws_region }
      ],
    }
  ])
  cpu                      = lookup(var.task_sizes[var.service_instance.inputs.task_size], "cpu")
  execution_role_arn       = var.environment.outputs.ServiceTaskDefExecutionRoleArn
  family                   = "${var.service.name}_${var.service_instance.name}"
  memory                   = lookup(var.task_sizes[var.service_instance.inputs.task_size], "memory")
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  task_role_arn            = aws_iam_role.service_task_def_role.arn
}

resource "aws_cloudwatch_log_group" "service_log_group" {
}

resource "aws_ecs_service" "service" {
  cluster                            = var.environment.outputs.ClusterName
  name                               = "${var.service.name}_${var.service_instance.name}"
  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 50
  desired_count                      = var.service_instance.inputs.desired_count
  enable_ecs_managed_tags            = false
  launch_type                        = "FARGATE"
  network_configuration {
    assign_public_ip = var.service_instance.inputs.subnet_type == "private" ? false : true
    security_groups  = [aws_security_group.service_security_group.id]
    subnets = var.service_instance.inputs.subnet_type == "private" ? [
      var.environment.outputs.PrivateSubnetOneId, var.environment.outputs.PrivateSubnetTwoId
      ] : [
      var.environment.outputs.PublicSubnetOneId, var.environment.outputs.PublicSubnetTwoId
    ]
  }

  service_registries {
    registry_arn = aws_service_discovery_service.cloudmap_service.arn
  }
  task_definition = aws_ecs_task_definition.service_task_def.arn
}

resource "aws_service_discovery_service" "cloudmap_service" {
  dns_config {
    dns_records {
      ttl  = 60
      type = "A"
    }
    namespace_id   = var.environment.outputs.CloudMapNamespaceId
    routing_policy = "MULTIVALUE"
  }
  health_check_custom_config {
    failure_threshold = 1
  }
  name         = "${var.service.name}.${var.service_instance.name}"
  namespace_id = var.environment.outputs.CloudMapNamespaceId
}

resource "aws_security_group" "service_security_group" {
  description = "Automatically created Security Group for the Service"

  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all inbound traffic by default"
    protocol    = "-1"
    to_port     = 0
    from_port   = 0
  }

  egress {
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic by default"
    protocol    = "-1"
    to_port     = 0
    from_port   = 0
  }
  vpc_id = var.environment.outputs.VpcId
}

resource "aws_appautoscaling_target" "service_task_count_target" {
  depends_on         = [aws_ecs_service.service]
  max_capacity       = 10
  min_capacity       = 1
  resource_id        = "service/${var.environment.outputs.ClusterName}/${aws_ecs_service.service.name}"
  role_arn           = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/ecs.application-autoscaling.amazonaws.com/AWSServiceRoleForApplicationAutoScaling_ECSService"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "service_task_count_target_cpu_scaling" {
  name               = "${aws_ecs_service.service.name}_BackendFargateServiceTaskCountTargetCpuScaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.service_task_count_target.resource_id
  scalable_dimension = aws_appautoscaling_target.service_task_count_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.service_task_count_target.service_namespace
  target_tracking_scaling_policy_configuration {
    target_value = 50
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}

resource "aws_appautoscaling_policy" "service_task_count_target_memory_scaling" {
  name               = "${aws_ecs_service.service.name}_BackendFargateServiceTaskCountTargetMemoryScaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.service_task_count_target.resource_id
  scalable_dimension = aws_appautoscaling_target.service_task_count_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.service_task_count_target.service_namespace
  target_tracking_scaling_policy_configuration {
    target_value = 50
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
  }
}
