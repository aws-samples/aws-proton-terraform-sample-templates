resource "aws_iam_role" "service-task-def-task-role" {
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy" "service-task-def-task-role-policy" {
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = "sns:Publish"
        Effect   = "Allow"
        Resource = var.environment.outputs.SnsTopicArn
      }
    ]
  })
  role = aws_iam_role.service-task-def-task-role.id
}

resource "aws_cloudwatch_log_group" "service-task-log-group" {
  name_prefix       = "${var.service_instance.name}-task-"
  retention_in_days = 0
}

resource "aws_ecs_task_definition" "scheduled-task-definition" {
  container_definitions = jsonencode([{
    essential : true,
    image : var.service_instance.inputs.image,
    logConfiguration : {
      logDriver : "awslogs",
      options : {
        awslogs-group : aws_cloudwatch_log_group.service-task-log-group.name,
        awslogs-stream-prefix : "${var.service.name}/${var.service_instance.name}",
        awslogs-region : local.region
      }
    },
    name : var.service_instance.name,
    environment : [
      {
        name : "SNS_TOPIC_ARN",
        value : "{ \"ping\" : \"${var.environment.outputs.SnsTopicArn}\" }"
      },
      {
        name : "SNS_REGION",
        value : var.environment.outputs.SnsRegion
      }
    ],
    portMappings = [
      {
        containerPort = tonumber(var.service_instance.inputs.port),
        hostPort      = 0
      }
    ]
    cpu : lookup(var.task_sizes[var.service_instance.inputs.task_size], "cpu")
    memory : lookup(var.task_sizes[var.service_instance.inputs.task_size], "memory")
  }])
  execution_role_arn       = var.environment.outputs.ServiceTaskDefExecutionRoleArn
  family                   = "${var.service.name}_${var.service_instance.name}"
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  task_role_arn            = aws_iam_role.service-task-def-task-role.arn
}

resource "aws_ecs_service" "service" {
  name                               = "${var.service.name}_${var.service_instance.name}"
  cluster                            = var.environment.outputs.ClusterName
  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 50
  desired_count                      = var.service_instance.inputs.desired_count
  enable_ecs_managed_tags            = false
  launch_type                        = "EC2"
  scheduling_strategy                = "REPLICA"
  service_registries {
    registry_arn   = aws_service_discovery_service.service_cloudmap_service.arn
    container_name = var.service_instance.name
    container_port = var.service_instance.inputs.port
  }
  task_definition = aws_ecs_task_definition.scheduled-task-definition.arn
}

resource "aws_service_discovery_service" "service_cloudmap_service" {
  name         = "${var.service.name}.${var.service_instance.name}"
  namespace_id = var.environment.outputs.CloudMapNamespaceId
  dns_config {
    namespace_id = var.environment.outputs.CloudMapNamespaceId
    dns_records {
      ttl  = 60
      type = "SRV"
    }
  }
  health_check_custom_config {
    failure_threshold = 1
  }
}

resource "aws_security_group_rule" "ecs_host_security_group_from_other_host_containers" {
  type                     = "ingress"
  protocol                 = -1
  from_port                = 0
  to_port                  = 65535
  security_group_id        = var.environment.outputs.EcsHostSecurityGroupId
  source_security_group_id = var.environment.outputs.EcsHostSecurityGroupId
  description              = "Ingress from other containers in the same security group"
}

resource "aws_appautoscaling_target" "service_task_count_target" {
  max_capacity       = 10
  min_capacity       = 1
  resource_id        = "service/${var.environment.outputs.ClusterName}/${var.service.name}_${var.service_instance.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
  depends_on = [
    aws_ecs_service.service
  ]
}

resource "aws_appautoscaling_policy" "service_task_count_target_cpu_scaling" {
  name               = "BackendECSEC2ServiceTaskCountTargetCpuScaling"
  resource_id        = aws_appautoscaling_target.service_task_count_target.resource_id
  policy_type        = "TargetTrackingScaling"
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
  name               = "BackendECSEC2ServiceTaskCountTargetCpuScaling"
  resource_id        = aws_appautoscaling_target.service_task_count_target.resource_id
  policy_type        = "TargetTrackingScaling"
  scalable_dimension = aws_appautoscaling_target.service_task_count_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.service_task_count_target.service_namespace
  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value = 50
  }
}
