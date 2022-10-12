variable "admin_email" {
  type = string
}

variable "admin_password" {
  type = string
}

variable "access_account_name" {
  type = string
}

variable "access_account_id" {
  type = string
}

variable "region" {
  type = string
}

variable "keypair" {
  type = string
}

variable "create_iam_roles" {
  type = bool
  default = false
}

variable "controller_license_type" {
  type = string
  default = null
}

variable "controller_license" {
  type = string
  default = null
}

variable "controller_version" {
  type = string
  default = "latest"
}

variable "permitted_prefixes" {
  type    = list(string)
  default = [ "0.0.0.0/0" ]
}

variable "name_prefix" {
  type = string
  default = null
}

variable "termination_protection" {
  type = bool
  default = false
}

variable "deploy_copilot" {
  type = bool
  default = true
}