terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

# security group
resource "aws_security_group" "sg" {
  name   = var.name
  vpc_id = var.vpc_id
  tags = {
    Name = var.name
  }
}

resource "aws_security_group_rule" "remote_in" {
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "all"
  cidr_blocks       = var.permitted_prefixes
  security_group_id = aws_security_group.sg.id
}

resource "aws_security_group_rule" "local_in" {
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "all"
  cidr_blocks       = [cidrsubnets(var.local_prefix, 1,1)[1]]
  security_group_id = aws_security_group.sg.id
}

resource "aws_security_group_rule" "gw_in" {
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "all"
  cidr_blocks       = [format("%s/32", var.peer.ip)]
  security_group_id = aws_security_group.sg.id
}

resource "aws_security_group_rule" "gw_ha_in" {
  count = var.peer.enable_ha ? 1:0
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "all"
  cidr_blocks       = [format("%s/32", var.peer.ip_ha)]
  security_group_id = aws_security_group.sg.id
}

# network interfaces
resource "aws_network_interface" "g1" {
  subnet_id = var.pub_subnet_id
  security_groups   = [aws_security_group.sg.id]
  source_dest_check = false
  tags = {
    Name = format("%s_%s_g1",var.name,var.peer.name)
  }
}

resource "aws_network_interface" "g2" {
  count = var.connection_type != "lan" ? 1:0
  subnet_id = var.pri_subnet_id
  security_groups   = [aws_security_group.sg.id]
  source_dest_check = false
  tags = {
    Name = format("%s_%s_g2",var.name,var.peer.name)
  }
}

resource "aws_network_interface" "g1_ha" {
  count = var.peer.enable_ha ? 1:0
  subnet_id = var.pub_subnet_id
  security_groups   = [aws_security_group.sg.id]
  source_dest_check = false
  tags = {
    Name = format("%s_%s-hagw_g1",var.name,var.peer.name)
  }
}

resource "aws_network_interface" "g2_ha" {
  count = var.peer.enable_ha && var.connection_type != "lan" ? 1:0
  subnet_id = var.pri_subnet_id
  security_groups   = [aws_security_group.sg.id]
  source_dest_check = false
  tags = {
    Name = format("%s_%s-hagw_g2",var.name,var.peer.name)
  }
}

# EIPs
resource "aws_eip" "eip" {
  vpc   = true
  tags = {
    Name = format("%s_%s_g1",var.name,var.peer.name)
  }
}

resource "aws_eip_association" "eip" {
  network_interface_id = aws_network_interface.g1.id
  allocation_id        = aws_eip.eip.id
}

resource "aws_eip" "eip_ha" {
  count = var.peer.enable_ha ? 1:0
  vpc   = true
  tags = {
    Name = format("%s_%s-hagw_g1",var.name,var.peer.name)
  }
}

resource "aws_eip_association" "eip_ha" {
  count = var.peer.enable_ha ? 1:0
  network_interface_id = aws_network_interface.g1_ha[0].id
  allocation_id        = aws_eip.eip_ha[0].id
}


# private route table
data "aws_route_table" "private" {
  subnet_id = var.pri_subnet_id
}

resource "aws_route" "route" {
  count = var.connection_type != "lan" ? 1:0
  route_table_id            = data.aws_route_table.private.id
  destination_cidr_block    = "0.0.0.0/0"
  network_interface_id = aws_network_interface.g2[0].id
}


# VPN Instance
resource "aws_instance" "cisco_csr_ipsec" {
  count = var.connection_type == "ipsec"? 1:0
  key_name      = var.aws_csr_settings.keypair
  ami           = var.aws_csr_settings.amis[var.region]
  instance_type = var.aws_csr_settings.size
  network_interface {
      network_interface_id = aws_network_interface.g1.id
      device_index         = 0
  }
  network_interface {
      network_interface_id = aws_network_interface.g2[0].id
      device_index         = 1
  }
  tags = {
    Name = var.name
  }
  user_data = var.peer.tunnel_type == "route" ? local.ios_ipsec_rb : local.ios_ipsec_pb
}

# VPN Instance HA
resource "aws_instance" "cisco_csr_ipsec_ha" {
  count = var.peer.enable_ha && var.connection_type == "ipsec" ? 1:0
  key_name      = var.aws_csr_settings.keypair
  ami           = var.aws_csr_settings.amis[var.region]
  instance_type = var.aws_csr_settings.size
  network_interface {
      network_interface_id = aws_network_interface.g1_ha[0].id
      device_index         = 0
  }
  network_interface {
      network_interface_id = aws_network_interface.g2_ha[0].id
      device_index         = 1
  }
  tags = {
    Name = format("%s_ha",var.name)
  }
  user_data = var.peer.tunnel_type == "route" ? local.ios_ipsec_rb_ha : local.ios_ipsec_pb_ha
}


# BGP over LAN Instance
resource "aws_instance" "cisco_csr_lan" {
  count = var.connection_type == "lan" ? 1:0
  key_name      = var.aws_csr_settings.keypair
  ami           = var.aws_csr_settings.amis[var.region]
  instance_type = var.aws_csr_settings.size
  network_interface {
      network_interface_id = aws_network_interface.g1.id
      device_index         = 0
  }
  tags = {
    Name = var.name
  }
  user_data = local.ios_lan
}
