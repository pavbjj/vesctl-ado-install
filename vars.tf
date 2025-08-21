variable "intermediate_cert" {
  type = string
}

variable "intermediate_namespace" {
  type = string
}

variable "certificates" {
  description = "List of certificate and key pairs"
  type = list(object({
    name = string
    cert = string
    key  = string
  }))
}
