variable "cloud_type" {
  type = number
}

variable "account_name" {
  type = string
}

variable "region" {
  type = string
}

variable "name" {
  type = string
}

variable "prefix" {
  type = string
  description = "The IP prefix, in CIDR format, for the vpc/vnet."
}

variable "type" {
  type = string
  validation {
    condition     = var.type == "transit" || var.type == "firenet" || var.type == "standard"
    error_message = "Improper network type. Supported values: transit, firenet, or standard"
  }
}
