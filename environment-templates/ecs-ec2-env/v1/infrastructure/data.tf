data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

resource "aws_sns_topic_policy" "ping_default" {
  arn = aws_sns_topic.ping_topic.arn

  policy = data.aws_iam_policy_document.ping_topic_policy.json
}

data "aws_iam_policy_document" "ping_topic_policy" {
  statement {
    effect = "Allow"

    actions = ["sns:Subscribe"]

    condition {
      test     = "StringEquals"
      variable = "sns:Protocol"
      values   = ["sqs"]
    }

    principals {
      identifiers = ["arn:${local.partition}:iam::${local.account_id}:root"]
      type        = "AWS"
    }

    resources = [aws_sns_topic.ping_topic.arn]
  }
}

resource "aws_lambda_permission" "ecs_drain_hook_function_allow_invoke_ecs_drain_hook_topic" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ecs_drain_function.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.ecs_drain_hook_topic.arn
}

resource "aws_sns_topic_subscription" "ecs_drain_hook_function_topic" {
  endpoint  = aws_lambda_function.ecs_drain_function.arn
  protocol  = "lambda"
  topic_arn = aws_sns_topic.ecs_drain_hook_topic.arn
}

resource "aws_iam_policy" "ecs_drain_hook_default_policy" {
  name_prefix = "ecs-drain-hook-default-"
  policy      = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Action   = [
          "sns:Publish",
        ]
        Effect   = "Allow"
        Resource = aws_sns_topic.ecs_drain_hook_topic.arn
      },
    ]
  })
}

resource "aws_iam_role" "ecs_drain_hook_role" {
  name_prefix        = "ecs-drain-hook-role"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "autoscaling.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role" "ecs_host_instance_role" {
  name_prefix        = "ecs-host-instance-role-"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "ec2.${local.partition_url_suffix}"
        }
      }
    ]
  })
}

resource "aws_iam_role" "ecs_drain_hook_function_service_role" {
  name_prefix         = "ecs-drain-hook-service-role-"
  assume_role_policy  = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
  managed_policy_arns = [
    "arn:${local.partition}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  ]
}

resource "aws_iam_policy" "ecs_drain_hook_function_service_role_default_policy" {
  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Action   = [
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceAttribute",
          "ec2:DescribeInstanceStatus",
          "ec2:DescribeHosts"
        ],
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action   = "autoscaling:CompleteLifecycleAction",
        Effect   = "Allow",
        Resource = "arn:${local.partition}:autoscaling:${local.region}:${local.account_id}:autoScalingGroup:*:autoScalingGroupName/${aws_autoscaling_group.ecs_autoscaling_group.name}"
      },
      {
        Action   = [
          "ecs:DescribeContainerInstances",
          "ecs:DescribeTasks",
          "ecs:ListContainerInstances",
          "ecs:SubmitContainerStateChange",
          "ecs:SubmitTaskStateChange",
          "ecs:UpdateContainerInstancesState",
          "ecs:ListTasks"
        ],
        Condition : {
          "ArnEquals" : {
            "ecs:cluster" : aws_ecs_cluster.cluster.arn
          }
        },
        Effect   = "Allow",
        Resource = "*"
      }
    ]
  })
  name   = "ecs_drain_hook_function_service_role_default_policy"
}

resource "aws_iam_role_policy_attachment" "ecs_drain_hook_function_service_role_default_policy" {
  role       = aws_iam_role.ecs_drain_hook_function_service_role.name
  policy_arn = aws_iam_policy.ecs_drain_hook_function_service_role_default_policy.arn
}

resource "aws_iam_role_policy_attachment" "ecs_drain_hook_policy_attachment" {
  policy_arn = aws_iam_policy.ecs_drain_hook_default_policy.arn
  role       = aws_iam_role.ecs_drain_hook_role.name
}

data "aws_ssm_parameter" "ecs_ami" {
  name = var.environment.inputs.ECSAMI
}

data "archive_file" "ecs_drain_hook_function" {
  source_file = "${path.module}/ecs_drain_hook_function/ecs_drain_hook_lambda.py"
  output_path = "${path.module}/ecs_drain_hook_function/ecs_drain_hook_lambda.zip"
  type        = "zip"
}