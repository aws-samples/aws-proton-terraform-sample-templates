variable "aws_region" {
  description = "AWS region where resources will be provisioned"
  type        = string
  default     = "us-west-2"
}

# required by proton
variable "environment" {
  description = "The Proton Environment"
  type = object({
    name   = string
    inputs = map(string)
  })
  default = null
}