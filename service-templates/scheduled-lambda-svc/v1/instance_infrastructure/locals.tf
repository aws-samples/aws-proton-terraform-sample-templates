locals {
  account_id                = data.aws_caller_identity.current.account_id
  region                    = data.aws_region.current.id
  partition                 = data.aws_partition.current.id
  using_default_lambda_code = try(var.service_instance.inputs.code_bucket, null) == null ? true : false
}