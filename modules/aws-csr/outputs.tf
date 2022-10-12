output "public_ip" {
    value = aws_eip.eip.public_ip
}

output "gw_tun_ip" {
    value = !var.peer.active_mesh ? format("%s/%s", cidrhost(var.peer.tun1_prefix, 2), split("/", var.peer.tun1_prefix)[1]) : (
    format("%s/%s,%s/%s", cidrhost(var.peer.tun1_prefix, 2), split("/", var.peer.tun1_prefix)[1], cidrhost(var.peer.tun2_prefix, 2), split("/", var.peer.tun2_prefix)[1]))
}

output "rem_tun_ip" {
    value = !var.peer.active_mesh ? format("%s/%s", cidrhost(var.peer.tun1_prefix, 1), split("/", var.peer.tun1_prefix)[1]) : ( 
    format("%s/%s,%s/%s", cidrhost(var.peer.tun1_prefix, 1), split("/", var.peer.tun1_prefix)[1], cidrhost(var.peer.tun2_prefix, 1), split("/", var.peer.tun2_prefix)[1]))
}

output "ipsec_key" {
    value = var.peer.ipsec_key
}


output "ha_enabled" {
    value = var.peer.enable_ha
}

output "peer_gw_ha" {
    value = var.peer.enable_ha ? format("%s-hagw",var.peer.name) : null
}

output "public_ip_ha" {
    value = length(aws_eip.eip_ha) > 0 ? aws_eip.eip_ha[0].public_ip : null
}

output "gw_tun_ip_ha" {
    value = var.peer.enable_ha ? !var.peer.active_mesh ? format("%s/%s", cidrhost(var.peer.tun1_prefix_ha, 2), split("/", var.peer.tun1_prefix_ha)[1]) : (
    format("%s/%s,%s/%s", cidrhost(var.peer.tun1_prefix_ha, 2), split("/", var.peer.tun1_prefix_ha)[1], cidrhost(var.peer.tun2_prefix_ha, 2), split("/", var.peer.tun2_prefix_ha)[1])) : null
}

output "rem_tun_ip_ha" {
    value = var.peer.enable_ha ? !var.peer.active_mesh ? format("%s/%s", cidrhost(var.peer.tun1_prefix_ha, 1), split("/", var.peer.tun1_prefix_ha)[1]) : (
    format("%s/%s,%s/%s", cidrhost(var.peer.tun1_prefix_ha, 1), split("/", var.peer.tun1_prefix_ha)[1], cidrhost(var.peer.tun2_prefix_ha, 1), split("/", var.peer.tun2_prefix_ha)[1])) : null
}

output "ipsec_key_ha" {
    value = var.peer.enable_ha ? var.peer.ipsec_key : null
}

output "remote_bgp_asn_ha" {
    value = var.peer.enable_ha ? var.remote_bgp_asn : null
}