locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.id
  partition  = data.aws_partition.current.id
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
