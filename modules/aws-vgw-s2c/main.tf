resource "aws_vpn_gateway" "vpn_gateway" {
  vpc_id = var.vpc_id
  tags = {
    Name = var.name
  }
}

resource "aws_customer_gateway" "gw" {
  device_name = var.peer.name
  bgp_asn    = 64513
  ip_address = var.peer.ip
  type       = "ipsec.1"
  tags = {
    Name = format("%s_%s",var.name,var.peer.name)
  }
}

resource "aws_customer_gateway" "gw_ha" {
    count = var.peer.enable_ha ? 1:0
  device_name = format("%s_ha",var.peer.name)
  bgp_asn    = 64513
  ip_address = var.peer.ip_ha
  type       = "ipsec.1"
  tags = {
    Name = format("%s_%s-hagw",var.name,var.peer.name)
  }
}

resource "aws_vpn_connection" "main" {
  vpn_gateway_id      = aws_vpn_gateway.vpn_gateway.id
  customer_gateway_id = aws_customer_gateway.gw.id
  type                = "ipsec.1"
  static_routes_only  = true
  tunnel1_inside_cidr = var.peer.tun1_prefix
  tunnel1_preshared_key = var.peer.ipsec_key
  tags = {
    Name = format("%s_%s",var.name,var.peer.name)
  }
}

resource "aws_vpn_connection" "ha" {
    count = var.peer.enable_ha ? 1:0
  vpn_gateway_id      = aws_vpn_gateway.vpn_gateway.id
  customer_gateway_id = aws_customer_gateway.gw_ha[0].id
  type                = "ipsec.1"
  static_routes_only  = true
  tunnel1_inside_cidr = var.peer.tun1_prefix_ha
  tunnel1_preshared_key = var.peer.ipsec_key
  tags = {
    Name = format("%s_%s-hagw",var.name,var.peer.name)
  }
}

resource "aws_vpn_connection_route" "ten" {
  destination_cidr_block = "10.0.0.0/8"
  vpn_connection_id      = aws_vpn_connection.main.id
}

resource "aws_vpn_connection_route" "oneseventwo" {
  destination_cidr_block = "172.16.0.0/12"
  vpn_connection_id      = aws_vpn_connection.main.id
}

resource "aws_vpn_connection_route" "oneninetwo" {
  destination_cidr_block = "192.168.0.0/16"
  vpn_connection_id      = aws_vpn_connection.main.id
}

resource "aws_vpn_connection_route" "ten_ha" {
  count = var.peer.enable_ha ? 1:0
  destination_cidr_block = "10.0.0.0/8"
  vpn_connection_id      = aws_vpn_connection.ha[0].id
}

resource "aws_vpn_connection_route" "oneseventwo_ha" {
  count = var.peer.enable_ha ? 1:0
  destination_cidr_block = "172.16.0.0/12"
  vpn_connection_id      = aws_vpn_connection.ha[0].id
}

resource "aws_vpn_connection_route" "oneninetwo_ha" {
  count = var.peer.enable_ha ? 1:0
  destination_cidr_block = "192.168.0.0/16"
  vpn_connection_id      = aws_vpn_connection.ha[0].id
}
