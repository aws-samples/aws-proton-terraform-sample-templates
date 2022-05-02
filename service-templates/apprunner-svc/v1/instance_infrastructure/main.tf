resource "aws_iam_role" "service_access_role" {
  name_prefix = "service_access_role"

  assume_role_policy = data.aws_iam_policy_document.service_access_assume_role.json
}

resource "aws_iam_policy" "publish_2_sns_role_policy" {
  name   = "publish_2_sns_role_policy"
  policy = data.aws_iam_policy_document.publish_2_sns.json
}

resource "aws_iam_role_policy_attachment" "publish_2_sns_role_policy_attachment" {
  policy_arn = aws_iam_policy.publish_2_sns_role_policy.arn
  role       = aws_iam_role.service_access_role.name
}

resource "aws_iam_policy" "service_access_role_default_policy" {
  name   = "service_access_role_default_policy"
  policy = data.aws_iam_policy_document.service_access_role_default_policy.json
}

resource "aws_iam_role_policy_attachment" "service_access_role_default_policy_attachment" {
  policy_arn = aws_iam_policy.service_access_role_default_policy.arn
  role       = aws_iam_role.service_access_role.name
}
resource "aws_apprunner_service" "service" {
  count        = lookup(var.service_instance.inputs, "image", "") != "" ? 1 : 0
  service_name = var.service.name

  network_configuration {
    egress_configuration {
      egress_type       = "VPC"
      vpc_connector_arn = var.environment.outputs.VpcConnectorArn
    }
  }

  source_configuration {
    authentication_configuration {
      access_role_arn = aws_iam_role.service_access_role.arn
    }
    image_repository {
      image_configuration {
        port = var.service_instance.inputs.port
        runtime_environment_variables = {
          "sns_topic_arn" = "{ping:${var.environment.outputs.SnsTopicArn}}"
          "sns_region"    = var.environment.outputs.SnsRegion
        }
      }
      image_identifier      = var.service_instance.inputs.image
      image_repository_type = "ECR"
    }
  }

  instance_configuration {
    cpu    = var.task_size_cpu[var.service_instance.inputs.task_size]
    memory = var.task_size_memory[var.service_instance.inputs.task_size]
  }
}