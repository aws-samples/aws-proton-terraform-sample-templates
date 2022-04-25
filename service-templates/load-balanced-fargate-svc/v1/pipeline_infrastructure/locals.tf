locals {
  account_id              = data.aws_caller_identity.current.account_id
  region                  = data.aws_region.current.id
  environment_account_ids = split(",", var.pipeline.inputs.environment_account_ids)
}

