output "public_ip" {
    value = aws_vpn_connection.main.tunnel1_address
}

output "gw_tun_ip" {
    value = format("%s/%s", aws_vpn_connection.main.tunnel1_cgw_inside_address, split("/", var.peer.tun1_prefix)[1])
}

output "rem_tun_ip" {
    value = format("%s/%s", aws_vpn_connection.main.tunnel1_vgw_inside_address, split("/", var.peer.tun1_prefix)[1])
}

output "ipsec_key" {
    value = var.peer.ipsec_key
}


output "ha_enabled" {
    value = length(aws_vpn_connection.ha) > 0
}

output "peer_gw_ha" {
    value = length(aws_vpn_connection.ha) > 0 ? format("%s-hagw",var.peer.name) : null
}

output "public_ip_ha" {
    value = length(aws_vpn_connection.ha) > 0 ? aws_vpn_connection.ha[0].tunnel1_address : null
}

output "gw_tun_ip_ha" {
    value = length(aws_vpn_connection.ha) > 0 ? format("%s/%s", aws_vpn_connection.ha[0].tunnel1_cgw_inside_address, split("/", var.peer.tun1_prefix_ha)[1]) : null
}

output "rem_tun_ip_ha" {
    value = length(aws_vpn_connection.ha) > 0 ? format("%s/%s", aws_vpn_connection.ha[0].tunnel1_vgw_inside_address, split("/", var.peer.tun1_prefix_ha)[1]) : null
}

output "ipsec_key_ha" {
    value = length(aws_vpn_connection.ha) > 0 ? var.peer.ipsec_key : null
}
