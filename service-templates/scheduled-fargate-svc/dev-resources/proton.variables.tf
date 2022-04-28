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

variable "environment" {
  type = object({
    outputs = map(string)
    name    = string
  })
  default = null
}

variable "service" {
  type = object({
    inputs = map(string)
    name   = string
  })
  default = null
}

variable "service_instance" {
  type = object({
    inputs = map(string)
    name   = string
  })
  default = null
}

variable "pipeline" {
  type = object({
    inputs = map(string)
  })
  default = null
}
