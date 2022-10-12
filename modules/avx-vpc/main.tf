terraform {
  required_providers {
    aviatrix = {
      source = "AviatrixSystems/aviatrix"
    }
  }
}

resource "aviatrix_vpc" "vpc" {
  cloud_type           = var.cloud_type
  account_name         = var.account_name
  region               = var.region
  name                 = replace(var.name, "_", "-")
  cidr                 = var.prefix
  aviatrix_transit_vpc = var.cloud_type == 1 && var.type == "transit"
  aviatrix_firenet_vpc = var.type == "firenet"
  subnet_size =  var.type == "standard" || (var.type == "transit" && var.cloud_type == 8) ? tonumber(split("/", var.prefix)[1])+3 : null
  num_of_subnet_pairs = var.cloud_type == 8 && (var.type == "standard" || var.type == "transit") ? 1 : (var.type == "standard" ? 2:null)
}

data "aws_availability_zones" "available" {
  count = var.cloud_type == 1 ? 1:0
  state = "available"
}