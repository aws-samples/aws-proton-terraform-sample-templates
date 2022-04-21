variable "environment" {
  type = object({
    inputs = map(string)
    name   = string
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
    inputs      = map(string)
    environment = map(string)
    name        = string
  })
  default = null
}

variable "pipeline" {
  type = object({
    inputs = map(string)
  })
  default = null
}