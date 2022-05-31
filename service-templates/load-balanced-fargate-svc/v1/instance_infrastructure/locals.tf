locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.id
  partition  = data.aws_partition.current.id

  component_outputs = can(var.service_instance.components.default) ? [
    for k, v in var.service_instance.components.default.outputs :
    { name : k, value : v }
  ] : []

  ecs_environment_variables = concat(local.component_outputs,
    [
      { name : "sns_topic_arn", value : "{ping:${var.environment.outputs.SnsTopicArn}" },
      { name : "sns_region", value : var.environment.outputs.SnsRegion },
      { name : "backend_url", value : var.service_instance.inputs.backendurl }
    ]
  )

  component_policy_arns = can(var.service_instance.components.default) ? [
    for k, v in var.service_instance.components.default.outputs :
    v if length(regexall("^arn:[a-zA-Z-]+:iam::\\d{12}:policy/.+", v)) > 0
  ] : []

}

variable "task_size_cpu" {
  type = map(string)
  default = {
    "x-small" = "256"
    "small"   = "512"
    "medium"  = "1024"
    "large"   = "2048"
    "x-large" = "4096"
  }
}

variable "task_size_memory" {
  type = map(string)
  default = {
    "x-small" = "512"
    "small"   = "1024"
    "medium"  = "2048"
    "large"   = "4096"
    "x-large" = "8192"
  }
}