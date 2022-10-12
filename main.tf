data "aviatrix_account" "all" {
  // this gets a list of accounts that are actually used within transit/spoke definitions
  for_each = { for v in distinct(concat([for v in var.transits: var.csps[v.csp].account], [for v in var.spokes: var.csps[v.csp].account])) : v=>true}
  account_name = each.key
}


# create transit networks
module "transit_gateway_networks" {
  source = "./modules/avx-vpc"
  for_each = {for k,v in var.transits: k=>v if !v.disabled}
  cloud_type = data.aviatrix_account.all[var.csps[each.value.csp].account].cloud_type
  account_name = var.csps[each.value.csp].account
  region = var.csps[each.value.csp].region
  name = each.key
  prefix = each.value.prefix
  type = each.value.enable_transit_firenet ? "firenet" : "transit"
}


# avx transit gateways
resource "aviatrix_transit_gateway" "all" {
    for_each = {for k,v in var.transits: k=>v if !v.disabled}
    cloud_type               = data.aviatrix_account.all[var.csps[each.value.csp].account].cloud_type
    account_name             = var.csps[each.value.csp].account
    gw_name                  = each.key
    vpc_id                   = module.transit_gateway_networks[each.key].vpc_id
    vpc_reg                  = var.csps[each.value.csp].region
    gw_size                  = each.value.size != null ? each.value.size : (  // if size provided, then use it
      each.value.hpe || each.value.enable_transit_firenet ? var.gw_sizes[each.value.csp].lg : ( // else if hpe or firenet, use large size
      var.gw_sizes[each.value.csp].sm)) // else use small size
    ha_gw_size               = !each.value.enable_ha ? null : ( // if no ha, then null
      each.value.size != null ? each.value.size : ( // if size provided, then use it
      each.value.hpe || each.value.enable_transit_firenet ? var.gw_sizes[each.value.csp].lg : ( // else if hpe or firenet, use large size
      var.gw_sizes[each.value.csp].sm )))  // else use small size
    subnet                   = each.value.hpe ? module.transit_gateway_networks[each.key].hpe_prefixes.primary : module.transit_gateway_networks[each.key].mgmt.prefix
    ha_subnet                = each.value.enable_ha ? (each.value.hpe ? module.transit_gateway_networks[each.key].hpe_prefixes.ha : module.transit_gateway_networks[each.key].mgmt_ha.prefix) : null
    insane_mode              = each.value.hpe
    insane_mode_az           = each.value.hpe ? module.transit_gateway_networks[each.key].hpe_prefixes.primary_az : null
    ha_insane_mode_az        = each.value.csp == "aws" && each.value.hpe && each.value.enable_ha ? module.transit_gateway_networks[each.key].hpe_prefixes.ha_az : null
    ha_zone                  = each.value.csp == "azure" && each.value.enable_ha ? "az-2" : null
    local_as_number          = each.value.bgp_asn
    enable_transit_firenet   = each.value.enable_transit_firenet
    enable_segmentation      = each.value.enable_segmentation
    connected_transit        = true
}

# transit peering
resource "aviatrix_transit_gateway_peering" "transit-peerings" {
  for_each = {for i,v in var.transit_peerings: i => v}
  transit_gateway_name1                       = aviatrix_transit_gateway.all[each.value.peer1].gw_name
  transit_gateway_name2                       = aviatrix_transit_gateway.all[each.value.peer2].gw_name
}

# create spoke networks
module "spoke_gateway_networks" {
  source = "./modules/avx-vpc"
  for_each = {for k,v in var.spokes: k=>v if !v.disabled}
  cloud_type = data.aviatrix_account.all[var.csps[each.value.csp].account].cloud_type
  account_name = var.csps[each.value.csp].account
  region = var.csps[each.value.csp].region
  name = each.key
  prefix = each.value.prefix
  type = "standard"
}

# avx spoke gateways
resource "aviatrix_spoke_gateway" "all" {
    for_each = {for k,v in var.spokes: k=>v if !v.disabled}
    cloud_type               = data.aviatrix_account.all[var.csps[each.value.csp].account].cloud_type
    account_name             = var.csps[each.value.csp].account
    gw_name                  = each.key
    vpc_id                   = module.spoke_gateway_networks[each.key].vpc_id
    vpc_reg                  = var.csps[each.value.csp].region
    gw_size                  = each.value.size != null ? each.value.size : (  // if size provided, then use it
      each.value.hpe ? var.gw_sizes[each.value.csp].lg : ( // else if hpe, use large size
      var.gw_sizes[each.value.csp].sm)) // else use small size
    ha_gw_size               = !each.value.enable_ha ? null : ( // if no ha, then null
      each.value.size != null ? each.value.size : ( // if size provided, then use it
      each.value.hpe ? var.gw_sizes[each.value.csp].lg : ( // else if hpe, use large size
      var.gw_sizes[each.value.csp].sm )))  // else use small size
    subnet                   = each.value.hpe ? module.spoke_gateway_networks[each.key].hpe_prefixes.primary : module.spoke_gateway_networks[each.key].public.prefix
    ha_subnet                = each.value.enable_ha ? (each.value.hpe ? module.spoke_gateway_networks[each.key].hpe_prefixes.ha : module.spoke_gateway_networks[each.key].public_ha.prefix) : null
    insane_mode              = each.value.hpe
    insane_mode_az           = each.value.hpe ? module.spoke_gateway_networks[each.key].hpe_prefixes.primary_az : null
    ha_insane_mode_az        = each.value.csp == "aws" && each.value.hpe && each.value.enable_ha ? module.spoke_gateway_networks[each.key].hpe_prefixes.ha_az : null
    ha_zone                  = each.value.csp == "azure" && each.value.enable_ha ? "az-2" : null
    local_as_number          = each.value.bgp_asn
    enable_bgp               = each.value.enable_bgp
}

# spoke to transit attachments
resource "aviatrix_spoke_transit_attachment" "all" {
  for_each = {for i,v in var.spoke_transit_attachments : i=>v}
  spoke_gw_name   = aviatrix_spoke_gateway.all[each.value.spoke].gw_name
  transit_gw_name = aviatrix_transit_gateway.all[each.value.transit].gw_name
}


# NETWORK SEGMENTATION
# domains
resource "aviatrix_segmentation_network_domain" "all" {
  count = length(var.net_seg_domains)
  domain_name = var.net_seg_domains[count.index]
}
# connection policies
resource "aviatrix_segmentation_network_domain_connection_policy" "all" {
  count = length(var.net_seg_connection_policies)
  domain_name_1 = var.net_seg_connection_policies[count.index].d1
  domain_name_2 = var.net_seg_connection_policies[count.index].d2
  depends_on = [aviatrix_segmentation_network_domain.all]
}
# associations
resource "aviatrix_segmentation_network_domain_association" "all" {
  for_each = var.net_seg_associations
  transit_gateway_name = aviatrix_transit_gateway.all[each.value.transit].gw_name
  network_domain_name  = each.key
  attachment_name      = aviatrix_spoke_gateway.all[each.value.spoke].gw_name
  depends_on = [aviatrix_segmentation_network_domain_connection_policy.all]
}


# EXTERNAL CONNECTIONS

# external connection networks
module "external_connection_networks" {
  source = "./modules/avx-vpc"
  for_each = {for k,v in var.external_connections: k=>v if !v.disabled}
  cloud_type = each.value.gw_type == "transit" ? data.aviatrix_account.all[var.csps[var.transits[each.value.gw_name].csp].account].cloud_type : (
    data.aviatrix_account.all[var.csps[var.spokes[each.value.gw_name].csp].account].cloud_type )
  account_name = each.value.gw_type == "transit" ? var.csps[var.transits[each.value.gw_name].csp].account : var.csps[var.spokes[each.value.gw_name].csp].account
  region = each.value.gw_type == "transit" ? var.csps[var.transits[each.value.gw_name].csp].region : var.csps[var.spokes[each.value.gw_name].csp].region
  name = each.key
  prefix = each.value.external_peer.prefix
  type = "standard"
}


# external connection vgw peers
#todo

# external connection aws_csr peers
module "external_connection_aws_csr_peers" {
  source = "./modules/aws-csr"
  for_each = {for k,v in var.external_connections: k=>v if !v.disabled && v.external_peer.type == "aws_csr"}
  aws_csr_settings = var.aws_csr_settings
  permitted_prefixes = var.permitted_prefixes
  local_prefix = each.value.external_peer.prefix
  connection_type = each.value.gw_type == "transit" && each.value.gre_only ? "gre" : "ipsec"
  region = var.csps.aws.region
  name = replace(each.key, "/w", "_")
  vpc_id = module.external_connection_networks[each.key].vpc_id
  pub_subnet_id = module.external_connection_networks[each.key].public.id
  pri_subnet_id = module.external_connection_networks[each.key].private.id
  remote_bgp_asn = each.value.external_peer.bgp_asn
  peer = {
    name: replace(each.value.gw_name, "/w", "_")
    ip: each.value.gw_type == "spoke" ? aviatrix_spoke_gateway.all[each.value.gw_name].eip : aviatrix_transit_gateway.all[each.value.gw_name].eip
    ipsec_key: replace(each.key, "/w", "_")
    tunnel_type: "route"
    tun1_prefix: each.value.tun1_prefix
    tun2_prefix: each.value.tun2_prefix
    enable_ha: each.value.gw_type == "spoke" ? var.spokes[each.value.gw_name].enable_ha : var.transits[each.value.gw_name].enable_ha
    active_mesh: each.value.gw_type == "spoke" ? var.spokes[each.value.gw_name].enable_ha : var.transits[each.value.gw_name].enable_ha
    ip_ha: each.value.gw_type == "spoke" ? aviatrix_spoke_gateway.all[each.value.gw_name].ha_eip : aviatrix_transit_gateway.all[each.value.gw_name].ha_eip
    tun1_prefix_ha: each.value.tun1_prefix_ha
    tun2_prefix_ha: each.value.tun2_prefix_ha
    bgp_asn: each.value.local_bgp_asn
  }
}

# transit external csr connections
resource "aviatrix_transit_external_device_conn" "aws_csr" {
  for_each = {for k,v in var.external_connections: k=>v if !v.disabled && v.gw_type == "transit" && v.external_peer.type == "aws_csr"}
  vpc_id                           = module.transit_gateway_networks[each.value.gw_name].vpc_id
  connection_name                  = replace(each.key, "/w", "_")
  gw_name                          = each.value.gw_name
  connection_type                  = each.value.local_bgp_asn == null ? "static" : "bgp"
  tunnel_protocol                  = each.value.gre_only ? "gre" : "ipsec"
  enable_ikev2                     = !each.value.gre_only
  bgp_local_as_num                 = var.transits[each.value.gw_name].bgp_asn != null ? var.transits[each.value.gw_name].bgp_asn : each.value.local_bgp_asn
  bgp_remote_as_num                = each.value.external_peer.bgp_asn
  remote_gateway_ip                = module.external_connection_aws_csr_peers[each.key].public_ip
  local_tunnel_cidr                = module.external_connection_aws_csr_peers[each.key].gw_tun_ip
  remote_tunnel_cidr               = module.external_connection_aws_csr_peers[each.key].rem_tun_ip
  pre_shared_key                   = module.external_connection_aws_csr_peers[each.key].ipsec_key
  ha_enabled                       = module.external_connection_aws_csr_peers[each.key].ha_enabled
  backup_remote_gateway_ip         = module.external_connection_aws_csr_peers[each.key].public_ip_ha
  backup_local_tunnel_cidr         = module.external_connection_aws_csr_peers[each.key].gw_tun_ip_ha
  backup_remote_tunnel_cidr        = module.external_connection_aws_csr_peers[each.key].rem_tun_ip_ha
  backup_pre_shared_key            = module.external_connection_aws_csr_peers[each.key].ipsec_key_ha
  backup_bgp_remote_as_num         = module.external_connection_aws_csr_peers[each.key].remote_bgp_asn_ha
}


# transit external aws_vgw connections
#todo

# spoke external csr connections
resource "aviatrix_spoke_external_device_conn" "aws_csr" {
  for_each = {for k,v in var.external_connections: k=>v if !v.disabled && v.gw_type == "spoke" && v.external_peer.type == "aws_csr"}
  vpc_id                           = module.spoke_gateway_networks[each.value.gw_name].vpc_id
  connection_name                  = replace(each.key, "/w", "_")
  gw_name                          = each.value.gw_name
  connection_type                  = each.value.local_bgp_asn == null ? "static" : "bgp"
  tunnel_protocol                  = "ipsec"
  enable_ikev2                     = true
  bgp_local_as_num                 = var.spokes[each.value.gw_name].bgp_asn != null ? var.spokes[each.value.gw_name].bgp_asn : each.value.local_bgp_asn
  bgp_remote_as_num                = each.value.external_peer.bgp_asn
  remote_gateway_ip                = module.external_connection_aws_csr_peers[each.key].public_ip
  local_tunnel_cidr                = module.external_connection_aws_csr_peers[each.key].gw_tun_ip
  remote_tunnel_cidr               = module.external_connection_aws_csr_peers[each.key].rem_tun_ip
  pre_shared_key                   = module.external_connection_aws_csr_peers[each.key].ipsec_key
  ha_enabled                       = module.external_connection_aws_csr_peers[each.key].ha_enabled
  backup_remote_gateway_ip         = module.external_connection_aws_csr_peers[each.key].public_ip_ha
  backup_local_tunnel_cidr         = module.external_connection_aws_csr_peers[each.key].gw_tun_ip_ha
  backup_remote_tunnel_cidr        = module.external_connection_aws_csr_peers[each.key].rem_tun_ip_ha
  backup_pre_shared_key            = module.external_connection_aws_csr_peers[each.key].ipsec_key_ha
  backup_bgp_remote_as_num         = module.external_connection_aws_csr_peers[each.key].remote_bgp_asn_ha
}

# spoke external aws_vgw connections
# todo



# SITE 2 CLOUD

# s2c networks
module "s2c_networks" {
  source = "./modules/avx-vpc"
  for_each = {for k,v in var.s2c: k=>v if !v.disabled}
  cloud_type = each.value.gw_type == "spoke" ? data.aviatrix_account.all[var.csps[var.spokes[each.value.gw_name].csp].account].cloud_type : (
    data.aviatrix_account.all[var.csps[var.transits[each.value.gw_name].csp].account].cloud_type )
  account_name = each.value.gw_type == "spoke" ? var.csps[var.spokes[each.value.gw_name].csp].account : var.csps[var.transits[each.value.gw_name].csp].account
  region = each.value.gw_type == "spoke" ? var.csps[var.spokes[each.value.gw_name].csp].region : var.csps[var.transits[each.value.gw_name].csp].region
  name = each.key
  prefix = each.value.external_peer.prefix
  type = "standard"
}

# s2c aws_csr peers
module "s2c_aws_csr_peers" {
  source = "./modules/aws-csr"
  for_each = {for k,v in var.s2c: k=>v if !v.disabled && v.external_peer.type == "aws_csr"}
  aws_csr_settings = var.aws_csr_settings
  permitted_prefixes = var.permitted_prefixes
  local_prefix = each.value.external_peer.prefix
  connection_type = "ipsec"
  region = var.csps.aws.region
  name = replace(each.key, "/w", "_")
  vpc_id = module.s2c_networks[each.key].vpc_id
  pub_subnet_id = module.s2c_networks[each.key].public.id
  pri_subnet_id = module.s2c_networks[each.key].private.id
  peer = {
    name: replace(each.value.gw_name, "/w", "_")
    ip: each.value.gw_type == "spoke" ? aviatrix_spoke_gateway.all[each.value.gw_name].eip : aviatrix_transit_gateway.all[each.value.gw_name].eip
    ipsec_key: replace(each.key, "/w", "_")
    tunnel_type: each.value.gw_type == "spoke" ? "route" : "policy"
    tun1_prefix: each.value.tun1_prefix
    enable_ha: each.value.gw_type == "spoke" ? var.spokes[each.value.gw_name].enable_ha : var.transits[each.value.gw_name].enable_ha
    ip_ha: each.value.gw_type == "spoke" ? aviatrix_spoke_gateway.all[each.value.gw_name].ha_eip : aviatrix_transit_gateway.all[each.value.gw_name].ha_eip
    tun1_prefix_ha: each.value.tun1_prefix_ha
  }
}

# s2c vgw peer
module "s2c_vgw_peers" {
  source = "./modules/aws-vgw-s2c"
  for_each = {for k,v in var.s2c: k=>v if !v.disabled && v.external_peer.type == "aws_vgw"}
  vpc_id = module.s2c_networks[each.key].vpc_id
  name = replace(each.key, "/w", "_")
  peer = {
    name: replace(each.value.gw_name, "/w", "_")
    ip: each.value.gw_type == "spoke" ? aviatrix_spoke_gateway.all[each.value.gw_name].eip : aviatrix_transit_gateway.all[each.value.gw_name].eip
    enable_ha: each.value.gw_type == "spoke" ? var.spokes[each.value.gw_name].enable_ha : var.transits[each.value.gw_name].enable_ha
    ip_ha: each.value.gw_type == "spoke" ? aviatrix_spoke_gateway.all[each.value.gw_name].ha_eip : aviatrix_transit_gateway.all[each.value.gw_name].ha_eip
    ipsec_key: replace(each.key, "/w", "_")
    tun1_prefix: each.value.tun1_prefix
    tun1_prefix_ha: each.value.tun1_prefix_ha
  }
}

# s2c csr connection
resource "aviatrix_site2cloud" "aws_csr" {
  for_each = {for k,v in var.s2c: k=>v if !v.disabled && v.external_peer.type == "aws_csr"}
  vpc_id                           = each.value.gw_type == "spoke" ? module.spoke_gateway_networks[each.value.gw_name].vpc_id : module.transit_gateway_networks[each.value.gw_name].vpc_id
  connection_name                  = replace(each.key, "/w", "_")
  remote_gateway_type              = "generic"
  tunnel_type                      = each.value.gw_type == "spoke" ? "route" : "policy"
  enable_ikev2                     = true
  primary_cloud_gateway_name       = each.value.gw_name
  remote_gateway_ip                = module.s2c_aws_csr_peers[each.key].public_ip
  local_tunnel_ip                  = module.s2c_aws_csr_peers[each.key].gw_tun_ip
  remote_tunnel_ip                 = module.s2c_aws_csr_peers[each.key].rem_tun_ip
  pre_shared_key                   = module.s2c_aws_csr_peers[each.key].ipsec_key
  ha_enabled                       = module.s2c_aws_csr_peers[each.key].ha_enabled
  enable_active_active             = each.value.gw_type == "transit"
  backup_gateway_name              = module.s2c_aws_csr_peers[each.key].peer_gw_ha
  backup_remote_gateway_ip         = module.s2c_aws_csr_peers[each.key].public_ip_ha
  backup_local_tunnel_ip           = module.s2c_aws_csr_peers[each.key].gw_tun_ip_ha
  backup_remote_tunnel_ip          = module.s2c_aws_csr_peers[each.key].rem_tun_ip_ha
  backup_pre_shared_key            = module.s2c_aws_csr_peers[each.key].ipsec_key_ha
  connection_type                  = each.value.unmapped != null || each.value.gw_type == "transit" ? "unmapped": "mapped"
  custom_mapped                    = false
  remote_subnet_cidr               = each.value.unmapped != null ? each.value.unmapped.site_prefix : each.value.mapped != null ? each.value.mapped.site_prefix : null
  local_subnet_cidr                = each.value.unmapped != null ? each.value.unmapped.cloud_prefix : each.value.mapped != null ? each.value.mapped.cloud_prefix : null
  remote_subnet_virtual            = each.value.mapped != null ? each.value.mapped.site_virtual : null
  local_subnet_virtual             = each.value.mapped != null ? each.value.mapped.cloud_virtual : null
}

# spoke s2c vgw connection -- no transit gw support, as vgw does not support policy-based vpn
resource "aviatrix_site2cloud" "vgw" {
  for_each = {for k,v in var.s2c: k=>v if !v.disabled && v.gw_type == "spoke" && v.external_peer.type == "aws_vgw"}
  vpc_id                           = module.spoke_gateway_networks[each.value.gw_name].vpc_id
  connection_name                  = replace(each.key, "/w", "_")
  remote_gateway_type              = "generic"
  tunnel_type                      = "route"
  enable_ikev2                     = true
  primary_cloud_gateway_name       = each.value.gw_name
  remote_gateway_ip                = module.s2c_vgw_peers[each.key].public_ip
  local_tunnel_ip                  = module.s2c_vgw_peers[each.key].gw_tun_ip
  remote_tunnel_ip                 = module.s2c_vgw_peers[each.key].rem_tun_ip
  pre_shared_key                   = module.s2c_vgw_peers[each.key].ipsec_key
  ha_enabled                       = module.s2c_vgw_peers[each.key].ha_enabled
  backup_gateway_name              = module.s2c_vgw_peers[each.key].peer_gw_ha
  backup_remote_gateway_ip         = module.s2c_vgw_peers[each.key].public_ip_ha
  backup_local_tunnel_ip           = module.s2c_vgw_peers[each.key].gw_tun_ip_ha
  backup_remote_tunnel_ip          = module.s2c_vgw_peers[each.key].rem_tun_ip_ha
  backup_pre_shared_key            = module.s2c_vgw_peers[each.key].ipsec_key_ha
  connection_type                  = each.value.unmapped != null ? "unmapped": "mapped"
  custom_mapped                    = false
  remote_subnet_cidr               = each.value.unmapped != null ? each.value.unmapped.site_prefix : each.value.mapped != null ? each.value.mapped.site_prefix : null
  local_subnet_cidr                = each.value.unmapped != null ? each.value.unmapped.cloud_prefix : each.value.mapped != null ? each.value.mapped.cloud_prefix : null
  remote_subnet_virtual            = each.value.mapped != null ? each.value.mapped.site_virtual : null
  local_subnet_virtual             = each.value.mapped != null ? each.value.mapped.cloud_virtual : null
}

