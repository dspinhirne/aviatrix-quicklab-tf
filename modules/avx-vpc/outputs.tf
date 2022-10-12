output "vpc_id" {
  value = aviatrix_vpc.vpc.vpc_id
}

output "mgmt" {
  value =  var.type != "standard" ? ({
    id: aviatrix_vpc.vpc.public_subnets[0].subnet_id
    prefix: aviatrix_vpc.vpc.public_subnets[0].cidr
  }) : {id:null, prefix:null}
}

output "mgmt_ha" {
  value =  var.type != "standard" ? ({
    id: var.cloud_type == 1 ? aviatrix_vpc.vpc.public_subnets[2].subnet_id : aviatrix_vpc.vpc.public_subnets[0].subnet_id
    prefix: var.cloud_type == 1 ? aviatrix_vpc.vpc.public_subnets[2].cidr : aviatrix_vpc.vpc.public_subnets[0].cidr
  }) : {id:null, prefix:null}
}

output "fw_ingress_egress" {
  value =  var.cloud_type == 1 && var.type != "standard" ? ({
    id: aviatrix_vpc.vpc.public_subnets[1].subnet_id
    prefix: aviatrix_vpc.vpc.public_subnets[1].cidr
  }) : {id:null, prefix:null}
}

output "fw_ingress_egress_ha" {
  value =  var.cloud_type == 1 && var.type != "standard" ? ({
    id: aviatrix_vpc.vpc.public_subnets[3].subnet_id
    prefix: aviatrix_vpc.vpc.public_subnets[3].cidr
  }) : {id:null, prefix:null}
}

output "fw_north" {
  value =  var.cloud_type == 1 && var.type == "transit" ? ({
    id: aviatrix_vpc.vpc.private_subnets[1].subnet_id
    prefix: aviatrix_vpc.vpc.private_subnets[1].cidr
  }) : {id:null, prefix:null}
}

output "fw_north_ha" {
  value =  var.cloud_type == 1 && var.type == "transit" ? ({
    id: aviatrix_vpc.vpc.private_subnets[3].subnet_id
    prefix: aviatrix_vpc.vpc.private_subnets[3].cidr
  }) : {id:null, prefix:null}
}

output "fw_south" {
  value =  var.cloud_type == 1 && var.type == "transit" ? ({
    id: aviatrix_vpc.vpc.private_subnets[0].subnet_id
    prefix: aviatrix_vpc.vpc.private_subnets[0].cidr
  }) : {id:null, prefix:null}
}

output "fw_south_ha" {
  value =  var.cloud_type == 1 && var.type == "transit" ? ({
    id: aviatrix_vpc.vpc.private_subnets[2].subnet_id
    prefix: aviatrix_vpc.vpc.private_subnets[2].cidr
  }) : {id:null, prefix:null}
}

output "public" {
  value =  var.type == "standard" ? ({
    id: var.cloud_type == 1 ? aviatrix_vpc.vpc.public_subnets[0].subnet_id : aviatrix_vpc.vpc.public_subnets[1].subnet_id
    prefix: var.cloud_type == 1 ? aviatrix_vpc.vpc.public_subnets[0].cidr : aviatrix_vpc.vpc.public_subnets[1].cidr
  }) : {id:null, prefix:null}
}

output "public_ha" {
  value =  var.type == "standard" ? ({
    id: var.cloud_type == 1 ? aviatrix_vpc.vpc.public_subnets[1].subnet_id : aviatrix_vpc.vpc.public_subnets[1].subnet_id
    prefix: var.cloud_type == 1 ? aviatrix_vpc.vpc.public_subnets[1].cidr : aviatrix_vpc.vpc.public_subnets[1].cidr
  }) : {id:null, prefix:null}
}

output "private" {
  value =  var.type == "standard" ? ({
    id: var.cloud_type == 1 ? aviatrix_vpc.vpc.private_subnets[0].subnet_id : aviatrix_vpc.vpc.private_subnets[0].subnet_id
    prefix: var.cloud_type == 1 ? aviatrix_vpc.vpc.private_subnets[0].cidr : aviatrix_vpc.vpc.private_subnets[0].cidr
  }) : {id:null, prefix:null}
}

output "private_ha" {
  value =  var.type == "standard" ? ({
    id: var.cloud_type == 1 ? aviatrix_vpc.vpc.private_subnets[1].subnet_id : aviatrix_vpc.vpc.private_subnets[0].subnet_id
    prefix: var.cloud_type == 1 ? aviatrix_vpc.vpc.private_subnets[1].cidr : aviatrix_vpc.vpc.private_subnets[0].cidr
  }) : {id:null, prefix:null}
}

output "hpe_prefixes" {
  value = {
    primary: cidrsubnet(var.prefix, 26 - tonumber(split("/", var.prefix)[1]), pow(2, 26 - tonumber(split("/", var.prefix)[1])) - 2 )
    primary_az: var.cloud_type != 1 ? null : data.aws_availability_zones.available[0].names[0] // only works for aws
    ha: cidrsubnet(var.prefix, 26 - tonumber(split("/", var.prefix)[1]), pow(2, 26 - tonumber(split("/", var.prefix)[1])) - 1 )
    ha_az: var.cloud_type != 1 ? null : data.aws_availability_zones.available[0].names[1] // only works for aws
  }
}