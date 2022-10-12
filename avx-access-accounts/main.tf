terraform {
  required_providers {
    aviatrix = {
      source = "AviatrixSystems/aviatrix"
    }
  }
}

data "aviatrix_account" "all" {
  for_each = {for i,v in concat(keys(var.aws_accounts), keys(var.azure_accounts)) : v => v}
  account_name = each.value
}

resource "aviatrix_account" "aws" {
  for_each = {for k,v in var.aws_accounts : k=>v if data.aviatrix_account.all[k].account_name == null}
  account_name = each.key
  cloud_type          = 1 
  aws_account_number = each.value.account_id
  aws_iam            = each.value.create_iam_roles
}

resource "aviatrix_account" "azure" {
  for_each = {for k,v in var.azure_accounts : k=>v if data.aviatrix_account.all[k].account_name == null}
  account_name = each.key
  cloud_type          = 8
  arm_subscription_id = each.value.sub_id
  arm_directory_id    = each.value.dir_id
  arm_application_id  = each.value.app_id
  arm_application_key = each.value.app_key
}
