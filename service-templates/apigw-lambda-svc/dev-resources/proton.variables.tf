
variable "service_instances" {
  type = list(
    object({
      name    = string
      inputs  = map(string)
      outputs = map(string)
      environment = object({
        account_id = string
        name       = string
        outputs    = map(string)
      })
    })
  )
}

variable "service" {
  type = object({
    name                      = string
    repository_id             = string
    repository_connection_arn = string
    branch_name               = string
  })
  default = null
}

variable "pipeline" {
  type = object({
    inputs = map(string)
  })
  default = null
}