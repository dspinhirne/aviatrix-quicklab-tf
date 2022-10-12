variable "aws_accounts" {
  type = map(object({
    account_id: string
    create_iam_roles: optional(bool,false)
  }))
  default = {}
}

variable "azure_accounts" {
  type = map(object({
      sub_id: string
      dir_id: string
      app_id: string
      app_key: string
  }))
  default = {}
}