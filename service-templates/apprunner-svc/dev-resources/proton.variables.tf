variable "environment" {
  type = object({
    account_id = string
    name       = string
    outputs    = map(string)
  })
  default = null
}

variable "service" {
  type = object({
    name                      = string
    branch_name               = string
    repository_connection_arn = string
    repository_id             = string
  })
}

variable "service_instance" {
  type = object({
    name       = string
    inputs     = map(string)
    components = map(string)
  })
  default = null
}

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

variable "pipeline" {
  type = object({
    inputs = map(string)
  })
  default = null
}