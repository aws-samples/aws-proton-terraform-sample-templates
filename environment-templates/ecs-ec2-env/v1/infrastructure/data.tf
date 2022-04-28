data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_sns_topic_policy" "ping_default" {
  arn = aws_sns_topic.ping_topic.arn

  policy = data.aws_iam_policy_document.ping_topic_policy.json
}

resource "aws_sns_topic_subscription" "ecs_drain_hook_function_topic" {
  endpoint  = aws_lambda_function.ecs_drain_function.arn
  protocol  = "lambda"
  topic_arn = aws_sns_topic.ecs_drain_hook_topic.arn
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

resource "aws_iam_policy" "ecs_drain_hook_default_policy" {
  name_prefix = "ecs-drain-hook-default-"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "sns:Publish",
        ]
        Effect   = "Allow"
        Resource = aws_sns_topic.ecs_drain_hook_topic.arn
      },
    ]
  })
}

resource "aws_iam_role" "ecs_drain_hook_role" {
  name_prefix = "ecs-drain-hook-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "autoscaling.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role" "ecs_host_instance_role" {
  name_prefix = "ecs-host-instance-role-"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.${local.partition_url_suffix}"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "ecs_host_instance_role_default_policy" {
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ecs:DeregisterContainerInstance",
          "ecs:RegisterContainerInstance",
          "ecs:Submit*"
        ],
        Effect   = "Allow"
        Resource = aws_ecs_cluster.cluster.arn
      },
      {
        Action = [
          "ecs:Poll",
          "ecs:StartTelemetrySession"
        ],
        Effect   = "Allow"
        Resource = "*"
        Condition : {
          "ArnEquals" : {
            "ecs:Cluster" : aws_ecs_cluster.cluster.arn
          }
        }
      },
      {
        Action = [
          "ecs:DiscoverPollEndpoint",
          "ecr:GetAuthorizationToken",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
  name_prefix = "ecs_host_instance_role_default_policy_"
}

resource "aws_iam_role" "ecs_drain_hook_function_service_role" {
  name_prefix = "ecs-drain-hook-service-role-"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
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
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
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
        Action = [
          "ecs:DescribeContainerInstances",
          "ecs:DescribeTasks",
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
      },
      {
        Action = [
          "ecs:ListContainerInstances",
          "ecs:SubmitContainerStateChange",
          "ecs:SubmitTaskStateChange"
        ],
        Effect   = "Allow",
        Resource = aws_ecs_cluster.cluster.arn
      }
    ]
  })
  name_prefix = "ecs_drain_hook_service_role_default"
}

resource "aws_iam_role" "service-task-def-execution-role" {
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  ]
}

resource "aws_iam_role_policy_attachment" "ecs_drain_hook_function_service_role_default_policy_attachment" {
  role       = aws_iam_role.ecs_drain_hook_function_service_role.name
  policy_arn = aws_iam_policy.ecs_drain_hook_function_service_role_default_policy.arn
}

resource "aws_iam_role_policy_attachment" "ecs_drain_hook_policy_attachment" {
  policy_arn = aws_iam_policy.ecs_drain_hook_default_policy.arn
  role       = aws_iam_role.ecs_drain_hook_role.name
}

resource "aws_iam_role_policy_attachment" "ecs_instance_role_policy_attachment" {
  policy_arn = aws_iam_policy.ecs_host_instance_role_default_policy.arn
  role       = aws_iam_role.ecs_host_instance_role.name
}

data "aws_ssm_parameter" "ami_id" {
  name = var.environment.inputs.ECSAMI
}

data "archive_file" "ecs_drain_hook_function" {
  type        = "zip"
  output_path = "ecs_drain_hook_lambda.zip"

  source {
    filename = "ecs_drain_hook_lambda.py"
    content  = <<-EOF
import boto3, json, os, time

ecs = boto3.client('ecs')
autoscaling = boto3.client('autoscaling')

def lambda_handler(event, context):
  print(json.dumps(event))
  cluster = os.environ['CLUSTER']
  snsTopicArn = event['Records'][0]['Sns']['TopicArn']
  lifecycle_event = json.loads(event['Records'][0]['Sns']['Message'])
  instance_id = lifecycle_event.get('EC2InstanceId')
  if not instance_id:
    print('Got event without EC2InstanceId: %s', json.dumps(event))
    return

  instance_arn = container_instance_arn(cluster, instance_id)
  print('Instance %s has container instance ARN %s' % (lifecycle_event['EC2InstanceId'], instance_arn))

  if not instance_arn:
    return

  task_arns = container_instance_task_arns(cluster, instance_arn)

  if task_arns:
    print('Instance ARN %s has task ARNs %s' % (instance_arn, ', '.join(task_arns)))

  while has_tasks(cluster, instance_arn, task_arns):
    time.sleep(10)

  try:
    print('Terminating instance %s' % instance_id)
    autoscaling.complete_lifecycle_action(
        LifecycleActionResult='CONTINUE',
        **pick(lifecycle_event, 'LifecycleHookName', 'LifecycleActionToken', 'AutoScalingGroupName'))
  except Exception as e:
    # Lifecycle action may have already completed.
    print(str(e))


def container_instance_arn(cluster, instance_id):
  """Turn an instance ID into a container instance ARN."""
  arns = ecs.list_container_instances(cluster=cluster, filter='ec2InstanceId==' + instance_id)['containerInstanceArns']
  if not arns:
    return None
  return arns[0]

def container_instance_task_arns(cluster, instance_arn):
  """Fetch tasks for a container instance ARN."""
  arns = ecs.list_tasks(cluster=cluster, containerInstance=instance_arn)['taskArns']
  return arns

def has_tasks(cluster, instance_arn, task_arns):
  """Return True if the instance is running tasks for the given cluster."""
  instances = ecs.describe_container_instances(cluster=cluster, containerInstances=[instance_arn])['containerInstances']
  if not instances:
    return False
  instance = instances[0]

  if instance['status'] == 'ACTIVE':
    # Start draining, then try again later
    set_container_instance_to_draining(cluster, instance_arn)
    return True

  task_count = None

  if task_arns:
    # Fetch details for tasks running on the container instance
    tasks = ecs.describe_tasks(cluster=cluster, tasks=task_arns)['tasks']
    if tasks:
      # Consider any non-stopped tasks as running
      task_count = sum(task['lastStatus'] != 'STOPPED' for task in tasks) + instance['pendingTasksCount']

  if not task_count:
    # Fallback to instance task counts if detailed task information is unavailable
    task_count = instance['runningTasksCount'] + instance['pendingTasksCount']

  print('Instance %s has %s tasks' % (instance_arn, task_count))

  return task_count > 0

def set_container_instance_to_draining(cluster, instance_arn):
  ecs.update_container_instances_state(
      cluster=cluster,
      containerInstances=[instance_arn], status='DRAINING')


def pick(dct, *keys):
  """Pick a subset of a dict."""
  return {k: v for k, v in dct.items() if k in keys}
EOF
  }
}