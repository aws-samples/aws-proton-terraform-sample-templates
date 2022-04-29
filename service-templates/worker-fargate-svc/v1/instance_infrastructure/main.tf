resource "aws_sqs_queue" "ecs_processing_dlq" {
  message_retention_seconds = 1209600
}

resource "aws_sqs_queue" "ecs_processing_queue" {
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.ecs_processing_dlq.arn
    maxReceiveCount     = 3
  })
}

resource "aws_sqs_queue_policy" "ecs_processing_queue_policy" {
  policy    = data.aws_iam_policy_document.ecs_processing_queue_policy_document.json
  queue_url = aws_sqs_queue.ecs_processing_queue.id
}

resource "aws_sns_topic_subscription" "ping_topic_subscription" {
  topic_arn = var.environment.outputs.SnsTopicArn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.ecs_processing_queue.arn
}

resource "aws_iam_role" "ecs_processing_queue_task_def_task_role" {
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

resource "aws_iam_role_policy_attachment" "ecs_processing_queue_task_def_task_role_policy_attachment" {
  policy_arn = aws_iam_policy.ecs_processing_queue_task_def_task_role_policy.arn
  role       = aws_iam_role.ecs_processing_queue_task_def_task_role.id
}

resource "aws_iam_policy" "ecs_processing_queue_task_def_task_role_policy" {
  policy = data.aws_iam_policy_document.ecs_processing_queue_task_def_task_role_policy_document.json
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

resource "aws_ecs_task_definition" "ecs_queue_processing_task_def" {
  container_definitions = jsonencode([
    {
      environment = [
        { name = "QUEUE_NAME", value = aws_sqs_queue.ecs_processing_queue.name },
        { name = "QUEUE_URI", value = aws_sqs_queue.ecs_processing_queue.url },
        { name = "QUEUE_REGION", value = var.aws_region }
      ],
      essential = true,
      image     = var.service_instance.inputs.image,
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          awslogs-group : aws_cloudwatch_log_group.ecs_queue_processing_log_group.name,
          awslogs-region : var.aws_region,
          awslogs-stream-prefix : "${var.service.name}/${var.service_instance.name}"
        }
      }
      name   = var.service_instance.name,
      cpu    = lookup(var.task_sizes[var.service_instance.inputs.task_size], "cpu")
      memory = lookup(var.task_sizes[var.service_instance.inputs.task_size], "memory")
    }
  ])
  family                   = "${var.service.name}_${var.service_instance.name}"
  cpu                      = 1024
  memory                   = 2048
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = var.environment.outputs.ServiceTaskDefExecutionRoleArn
  task_role_arn            = aws_iam_role.ecs_processing_queue_task_def_task_role.arn
}

resource "aws_cloudwatch_log_group" "ecs_queue_processing_log_group" {

}

resource "aws_ecs_service" "ecs_queue_processing_ecs_fargate_service" {
  cluster                            = var.environment.outputs.ClusterName
  name                               = "${var.service.name}_${var.service_instance.name}"
  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 50
  desired_count                      = var.service_instance.inputs.desired_count
  enable_ecs_managed_tags            = false
  launch_type                        = "FARGATE"
  scheduling_strategy                = "REPLICA"
  task_definition                    = aws_ecs_task_definition.ecs_queue_processing_task_def.arn

  network_configuration {
    subnets = var.service_instance.inputs.subnet_type == "private" ? [
      var.environment.outputs.PrivateSubnetOneId,
      var.environment.outputs.PrivateSubnetTwoId
      ] : [
      var.environment.outputs.PublicSubnetOneId,
      var.environment.outputs.PublicSubnetTwoId
    ]
    assign_public_ip = var.service_instance.inputs.subnet_type == "private" ? false : true
  }
}

resource "aws_security_group" "ecs_queue_processing_ecs_fargate_service_security_group" {
  description = "Automatically created Security Group for the Service"
  egress {
    from_port   = 0
    protocol    = "-1"
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
  vpc_id = var.environment.outputs.VpcId
}

resource "aws_appautoscaling_target" "ecs_queue_processing_ecs_fargate_service_task_count_target" {
  max_capacity       = 10
  min_capacity       = 1
  resource_id        = "service/${var.environment.outputs.ClusterName}/${aws_ecs_service.ecs_queue_processing_ecs_fargate_service.name}"
  role_arn           = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/ecs.application-autoscaling.amazonaws.com/AWSServiceRoleForApplicationAutoScaling_ECSService"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "ecs_queue_processing_ecs_fargate_service_task_count_target_cpu_scaling" {
  name               = "WorkerECSEC2ServiceTaskCountTargetCpuScaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_queue_processing_ecs_fargate_service_task_count_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_queue_processing_ecs_fargate_service_task_count_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_queue_processing_ecs_fargate_service_task_count_target.service_namespace
  target_tracking_scaling_policy_configuration {
    target_value = 50
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}

resource "aws_appautoscaling_policy" "ecs_queue_processing_ecs_fargate_service_task_count_target_queue_messages_visible_lower_policy" {
  name               = "WorkerECSEC2ServiceTaskCountTargetQueueMessagesVisibleScalingLowerPolicy"
  policy_type        = "StepScaling"
  resource_id        = aws_appautoscaling_target.ecs_queue_processing_ecs_fargate_service_task_count_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_queue_processing_ecs_fargate_service_task_count_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_queue_processing_ecs_fargate_service_task_count_target.service_namespace
  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    metric_aggregation_type = "Maximum"
    step_adjustment {
      scaling_adjustment          = -1
      metric_interval_upper_bound = 0
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "ecs_queue_processing_ecs_fargate_service_task_count_target_queue_messages_visible_lower_alarm" {
  alarm_name          = "${var.service.name}_${var.service_instance.name}_lower_threshold_scaling"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = 1
  alarm_actions = [
    aws_appautoscaling_policy.ecs_queue_processing_ecs_fargate_service_task_count_target_queue_messages_visible_lower_policy.arn
  ]
  alarm_description = "Lower threshold scaling alarm"
  dimensions = {
    Name  = "QueueName"
    Value = aws_sqs_queue.ecs_processing_queue.name
  }
  metric_name = "ApproximateNumberOfMessagesVisible"
  namespace   = "AWS/SQS"
  period      = 300
  statistic   = "Maximum"
  threshold   = 0
}

resource "aws_appautoscaling_policy" "ecs_queue_processing_ecs_fargate_service_task_count_target_queue_messages_visible_upper_policy" {
  name               = "WorkerECSEC2ServiceTaskCountTargetQueueMessagesVisibleScalingUpperPolicy"
  policy_type        = "StepScaling"
  resource_id        = aws_appautoscaling_target.ecs_queue_processing_ecs_fargate_service_task_count_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_queue_processing_ecs_fargate_service_task_count_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_queue_processing_ecs_fargate_service_task_count_target.service_namespace
  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    metric_aggregation_type = "Maximum"
    step_adjustment {
      scaling_adjustment          = 1
      metric_interval_upper_bound = 400
      metric_interval_lower_bound = 0
    }
    step_adjustment {
      scaling_adjustment          = 5
      metric_interval_lower_bound = 400
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "ecs_queue_processing_ecs_fargate_service_task_count_target_queue_messages_visible_upper_alarm" {
  alarm_name          = "${var.service.name}_${var.service_instance.name}_upper_threshold_scaling"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  alarm_actions = [
    aws_appautoscaling_policy.ecs_queue_processing_ecs_fargate_service_task_count_target_queue_messages_visible_upper_policy.arn
  ]
  alarm_description = "Upper threshold scaling alarm"
  dimensions = {
    Name  = "QueueName"
    Value = aws_sqs_queue.ecs_processing_queue.name
  }
  metric_name = "ApproximateNumberOfMessagesVisible"
  namespace   = "AWS/SQS"
  period      = 300
  statistic   = "Maximum"
  threshold   = 100
}
