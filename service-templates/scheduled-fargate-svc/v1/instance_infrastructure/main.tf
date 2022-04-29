resource "aws_cloudwatch_event_rule" "event_rule" {
  name                = "ecs_task_event_rule"
  schedule_expression = "rate(5 minutes)"
  is_enabled          = true
  role_arn            = aws_iam_role.schedule_task_def_event_role.arn
}

resource "aws_cloudwatch_event_target" "ecs_scheduled_task" {
  target_id = "Target0"
  arn       = var.environment.outputs.ClusterArn
  rule      = aws_cloudwatch_event_rule.event_rule.name
  role_arn  = aws_iam_role.schedule_task_def_event_role.arn

  ecs_target {
    launch_type         = "FARGATE"
    task_count          = 1
    task_definition_arn = aws_ecs_task_definition.ecs_task_definition_local.arn

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
}

resource "aws_ecs_task_definition" "ecs_task_definition_local" {
  family = "${var.service.name}_${var.service_instance.name}"
  cpu    = 1024
  memory = 2048
  container_definitions = jsonencode([{
    name : "${var.service_instance.name}-bar",
    image : var.service_instance.inputs.image,
    cpu : 256
    memory : 512
    essential : true,
    logConfiguration : {
      logDriver : "awslogs",
      options : {
        awslogs-group : aws_cloudwatch_log_group.ecs_task.name,
        awslogs-stream-prefix : "${var.service.name}/${var.service_instance.name}",
        awslogs-region : local.region
      }
    },
    environment : [
      {
        name : "SNS_TOPIC_ARN",
        value : "{ \"ping\" : \"${var.environment.outputs.SnsTopicArn}\" }"
      },
      {
        name : "SNS_REGION",
        value : var.environment.outputs.SnsRegion
      }
    ]
  }])
  task_role_arn            = aws_iam_role.schedule_task_def_task_role.arn
  execution_role_arn       = var.environment.outputs.ServiceTaskDefExecutionRoleArn
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
}

resource "aws_cloudwatch_log_group" "ecs_task" {
  retention_in_days = 0
}

resource "aws_iam_role" "schedule_task_def_event_role" {
  name = "schedule_task_def_event_role"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "schedule_task_def_event_role_policy" {
  role = aws_iam_role.schedule_task_def_event_role.id

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ecs:RunTask",
        ]
        Effect    = "Allow"
        Resource  = aws_ecs_task_definition.ecs_task_definition_local.arn
        Condition = { "ArnEquals" : { "ecs:cluster" : "${var.environment.outputs.ClusterArn}" } }
      },
      {
        Action = [
          "iam:PassRole",
        ]
        Effect   = "Allow"
        Resource = var.environment.outputs.ServiceTaskDefExecutionRoleArn
      },
      {
        Action = [
          "iam:PassRole",
        ]
        Effect   = "Allow"
        Resource = aws_iam_role.schedule_task_def_task_role.arn
      }
    ]
  })
}

resource "aws_iam_role" "schedule_task_def_task_role" {

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

resource "aws_iam_role_policy" "scheduled-task-def-task-role-policy" {
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
  role = aws_iam_role.schedule_task_def_task_role.id
}
