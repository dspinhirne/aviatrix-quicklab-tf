# cisco csr settings
variable "aws_csr_settings" {
  type = object({
    username: string
    password: string
    keypair: string
    size: optional(string,"t2.medium")
    amis: optional(map(string),{"us-east-1" = "ami-06673acad74a19508"})
  })
  default = null
}

variable "permitted_prefixes" {
  type    = list(string)
}

variable "local_prefix" {
  type = string
}

variable "region" {
  type = string
}

variable "name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "pub_subnet_id" {
  type = string
}

variable "pri_subnet_id" {
  type = string
}

variable "remote_bgp_asn" {
  type = number
  default = null
}

variable "connection_type" {
  type = string
  validation {
    condition     = var.connection_type == "ipsec" || var.connection_type == "gre" || var.connection_type == "lan"
    error_message = "Improper network type. Supported values: ipsec, gre, or lan"
  }
}

variable "peer" {
  type = object({
    name: string
    ip: string
    bgp_asn: optional(number, null)
    ipsec_key: string
    tunnel_type: optional(string, "route")
    tun1_prefix: optional(string, null)
    tun2_prefix: optional(string, null)
    enable_ha: optional(bool, false)
    active_mesh: optional(bool, false)
    ip_ha: optional(string,null)
    tun1_prefix_ha: optional(string, null)
    tun2_prefix_ha: optional(string, null)
  })
}



locals {
  ios_lan =  <<EOT
    ios-config-001="hostname ${replace(var.name, "/w", "-")}"
    ios-config-002="username ${var.aws_csr_settings.username} privilege 15 password 0 ${var.aws_csr_settings.password}"

    %{ if var.peer.bgp_asn != null }
      ios-config-200="router bgp ${var.remote_bgp_asn}"
      ios-config-201="bgp log-neighbor-changes"
      ios-config-210="neighbor ${var.peer.ip} remote-as ${var.peer.bgp_asn}"
      ios-config-211="neighbor ${var.peer.ip} timers 50 180"
      %{ if var.peer.ip_ha != null}
        ios-config-212="neighbor ${var.peer.ip_ha} remote-as ${var.peer.bgp_asn}"
        ios-config-213="neighbor ${var.peer.ip_ha} timers 50 180"
      %{ endif }
      ios-config-214="exit"
      ios-config-220="address-family ipv4 unicast"
      ios-config-221="redistribute connected"
      ios-config-222="maximum-paths 2"
      ios-config-223="neighbor ${var.peer.ip} activate"
      ios-config-224="neighbor ${var.peer.ip} soft-reconfiguration inbound"
      %{ if var.peer.ip_ha != null}
        ios-config-225="neighbor ${var.peer.ip_ha} activate"
        ios-config-226="neighbor ${var.peer.ip_ha} soft-reconfiguration inbound"
      %{ endif }
      ios-config-227="exit-address-family"
    %{ endif }

    %{ if var.peer.bgp_asn == null }
      ios-config-300="10.0.0.0 255.0.0.0 ${var.peer.ip}"
      ios-config-301="172.16 255.240.0.0 ${var.peer.ip}"
      ios-config-302="192.168.0.0 255.255.0.0 ${var.peer.ip}"
      %{ if var.peer.ip_ha != null}
        ios-config-303="10.0.0.0 255.0.0.0 ${var.peer.ip_ha}"
        ios-config-304="172.16 255.240.0.0 ${var.peer.ip_ha}"
        ios-config-305="192.168.0.0 255.255.0.0 ${var.peer.ip_ha}"
      %{ endif }
    %{ endif }
    EOT

  ios_ipsec_rb = <<EOT
    ios-config-001="hostname ${replace(var.name, "/w", "-")}"
    ios-config-002="username ${var.aws_csr_settings.username} privilege 15 password 0 ${var.aws_csr_settings.password}"

    ios-config-010="crypto ikev2 proposal ikev2-prop-${var.peer.name}"
    ios-config-011="encryption aes-cbc-256"
    ios-config-012="integrity sha256"
    ios-config-013="group 14"
    ios-config-014="exit"

    ios-config-020="crypto ikev2 policy 1"
    ios-config-021="match fvrf any"
    ios-config-022="proposal ikev2-prop-${var.peer.name}"
    ios-config-023="exit"

    ios-config-030="crypto ipsec transform-set ipsec-ts-${var.peer.name} esp-aes 256 esp-sha256-hmac"
    ios-config-031="mode tunnel"
    ios-config-032="exit"

    ios-config-040="crypto ipsec df-bit clear"

    ios-config-100="crypto ikev2 keyring keyring-tun1"
    ios-config-101="peer ${var.peer.ip}"
    ios-config-102="address ${var.peer.ip}"
    ios-config-103="identity address ${aws_eip.eip.public_ip}"
    ios-config-104="pre-shared-key ${var.peer.ipsec_key}"
    ios-config-105="exit"
    ios-config-106="exit"

    ios-config-110="crypto ikev2 profile ikev2-prof-tun1"
    ios-config-111="match identity remote address ${var.peer.ip} 255.255.255.255"
    ios-config-112="identity local address ${aws_eip.eip.public_ip}"
    ios-config-113="authentication remote pre-share"
    ios-config-114="authentication local pre-share"
    ios-config-115="keyring local keyring-tun1"
    ios-config-116="lifetime 28800"
    ios-config-117="dpd 10 3 periodic"
    ios-config-118="exit"

    ios-config-120="crypto ipsec profile ipsec-prof-tun1"
    ios-config-121="set security-association lifetime seconds 3600"
    ios-config-122="set transform-set ipsec-ts-${var.peer.name}"
    ios-config-123="set pfs group14"
    ios-config-124="set ikev2-profile ikev2-prof-tun1"
    ios-config-125="set security-association lifetime kilobytes disable"
    ios-config-126="set security-association lifetime seconds 3600"
    ios-config-127="exit"

    %{if var.peer.active_mesh}
      ios-config-130="crypto ikev2 keyring keyring-tun2"
      ios-config-131="peer ${var.peer.ip_ha}"
      ios-config-132="address ${var.peer.ip_ha}"
      ios-config-133="identity address ${aws_eip.eip_ha[0].public_ip}"
      ios-config-134="pre-shared-key ${var.peer.ipsec_key}"
      ios-config-135="exit"
      ios-config-136="exit"

      ios-config-140="crypto ikev2 profile ikev2-prof-tun2"
      ios-config-141="match identity remote address ${var.peer.ip_ha} 255.255.255.255"
      ios-config-142="identity local address ${aws_eip.eip_ha[0].public_ip}"
      ios-config-143="authentication remote pre-share"
      ios-config-144="authentication local pre-share"
      ios-config-145="keyring local keyring-tun2"
      ios-config-146="lifetime 28800"
      ios-config-147="dpd 10 3 periodic"
      ios-config-148="exit"

      ios-config-150="crypto ipsec profile ipsec-prof-tun2"
      ios-config-151="set security-association lifetime seconds 3600"
      ios-config-152="set transform-set ipsec-ts-${var.peer.name}"
      ios-config-153="set pfs group14"
      ios-config-154="set ikev2-profile ikev2-prof-tun2"
      ios-config-155="set security-association lifetime kilobytes disable"
      ios-config-156="set security-association lifetime seconds 3600"
      ios-config-157="exit"
    %{ endif }

    ios-config-160="interface Tunnel 1"
    ios-config-161="ip address ${format("%s %s", cidrhost(var.peer.tun1_prefix, 1), cidrnetmask(var.peer.tun1_prefix))}"
    ios-config-162="ip mtu 1436"
    ios-config-163="ip tcp adjust-mss 1387"
    ios-config-164="tunnel source GigabitEthernet1"
    ios-config-165="tunnel mode ipsec ipv4"
    ios-config-166="tunnel protection ipsec profile ipsec-prof-tun1"
    ios-config-167="tunnel destination ${var.peer.ip}"
    ios-config-168="ip virtual-reassembly"
    ios-config-169="exit"

    %{ if var.peer.active_mesh}
      ios-config-170="interface Tunnel 2"
      ios-config-171="ip address ${format("%s %s", cidrhost(var.peer.tun2_prefix, 1), cidrnetmask(var.peer.tun2_prefix))}"
      ios-config-172="ip mtu 1436"
      ios-config-173="ip tcp adjust-mss 1387"
      ios-config-174="tunnel source GigabitEthernet1"
      ios-config-175="tunnel mode ipsec ipv4"
      ios-config-176="tunnel protection ipsec profile ipsec-prof-tun2"
      ios-config-177="tunnel destination ${var.peer.ip_ha}"
      ios-config-178="ip virtual-reassembly"
      ios-config-179="exit"
    %{ endif }

    ios-config-180="interface GigabitEthernet2"
    ios-config-181="ip address dhcp"
    ios-config-182="ip nat outside"
    ios-config-183="negotiation auto"
    ios-config-184="no shutdown"
    ios-config-185="exit"

    %{ if var.peer.bgp_asn != null }
      ios-config-200="router bgp ${var.remote_bgp_asn}"
      ios-config-201="bgp log-neighbor-changes"
      ios-config-210="neighbor ${cidrhost(var.peer.tun1_prefix, 2)} remote-as ${var.peer.bgp_asn}"
      ios-config-211="neighbor ${cidrhost(var.peer.tun1_prefix, 2)} timers 50 180"
      %{ if var.peer.active_mesh}
        ios-config-212="neighbor ${cidrhost(var.peer.tun2_prefix, 2)} remote-as ${var.peer.bgp_asn}"
        ios-config-213="neighbor ${cidrhost(var.peer.tun2_prefix, 2)} timers 50 180"
      %{ endif }
      ios-config-220="address-family ipv4 unicast"
      ios-config-221="redistribute connected"
      ios-config-222="maximum-paths 2"
      ios-config-223="neighbor ${cidrhost(var.peer.tun1_prefix, 2)} activate"
      ios-config-224="neighbor ${cidrhost(var.peer.tun1_prefix, 2)} soft-reconfiguration inbound"
      %{ if var.peer.active_mesh}
        ios-config-225="neighbor ${cidrhost(var.peer.tun2_prefix, 2)} activate"
        ios-config-226="neighbor ${cidrhost(var.peer.tun2_prefix, 2)} soft-reconfiguration inbound"
      %{ endif }
      ios-config-227="exit-address-family"
      ios-config-228="exit"
    %{ endif }

    %{ if var.peer.bgp_asn == null }
      ios-config-300="10.0.0.0 255.0.0.0 Tunnel 1"
      ios-config-301="172.16 255.240.0.0 Tunnel 1"
      ios-config-302="192.168.0.0 255.255.0.0 Tunnel 1"
      %{ if var.peer.active_mesh}
        ios-config-303="10.0.0.0 255.0.0.0 Tunnel 2"
        ios-config-304="172.16 255.240.0.0 Tunnel 2"
        ios-config-305="192.168.0.0 255.255.0.0 Tunnel 2"
      %{ endif }
    %{ endif }
  EOT

  ios_ipsec_rb_ha = <<EOT
  ios-config-001="hostname ${replace(var.name, "/w", "-")}_ha"
  ios-config-002="username ${var.aws_csr_settings.username} privilege 15 password 0 ${var.aws_csr_settings.password}"

  ios-config-010="crypto ikev2 proposal ikev2-prop-${var.peer.name}"
  ios-config-011="encryption aes-cbc-256"
  ios-config-012="integrity sha256"
  ios-config-013="group 14"
  ios-config-014="exit"

  ios-config-020="crypto ikev2 policy 1"
  ios-config-021="match fvrf any"
  ios-config-022="proposal ikev2-prop-${var.peer.name}"
  ios-config-023="exit"

  ios-config-030="crypto ipsec transform-set ipsec-ts-${var.peer.name} esp-aes 256 esp-sha256-hmac"
  ios-config-031="mode tunnel"
  ios-config-032="exit"

  ios-config-040="crypto ipsec df-bit clear"

  %{if var.peer.active_mesh}
    ios-config-100="crypto ikev2 keyring keyring-tun1"
    ios-config-101="peer ${var.peer.ip}"
    ios-config-102="address ${var.peer.ip}"
    ios-config-103="identity address ${aws_eip.eip.public_ip}"
    ios-config-104="pre-shared-key ${var.peer.ipsec_key}"
    ios-config-105="exit"
    ios-config-106="exit"

    ios-config-110="crypto ikev2 profile ikev2-prof-tun1"
    ios-config-111="match identity remote address ${var.peer.ip} 255.255.255.255"
    ios-config-112="identity local address ${aws_eip.eip.public_ip}"
  %{ endif }
  %{if !var.peer.active_mesh && var.peer.enable_ha}
    ios-config-100="crypto ikev2 keyring keyring-tun1"
    ios-config-101="peer ${var.peer.ip_ha}"
    ios-config-102="address ${var.peer.ip_ha}"
    ios-config-103="identity address ${aws_eip.eip_ha[0].public_ip}"
    ios-config-104="pre-shared-key ${var.peer.ipsec_key}"
    ios-config-105="exit"
    ios-config-106="exit"

    ios-config-110="crypto ikev2 profile ikev2-prof-tun1"
    ios-config-111="match identity remote address ${var.peer.ip_ha} 255.255.255.255"
    ios-config-112="identity local address ${aws_eip.eip_ha[0].public_ip}"
  %{ endif }

  ios-config-113="authentication remote pre-share"
  ios-config-114="authentication local pre-share"
  ios-config-115="keyring local keyring-tun1"
  ios-config-116="lifetime 28800"
  ios-config-117="dpd 10 3 periodic"
  ios-config-118="exit"

  ios-config-120="crypto ipsec profile ipsec-prof-tun1"
  ios-config-121="set security-association lifetime seconds 3600"
  ios-config-122="set transform-set ipsec-ts-${var.peer.name}"
  ios-config-123="set pfs group14"
  ios-config-124="set ikev2-profile ikev2-prof-tun1"
  ios-config-125="set security-association lifetime kilobytes disable"
  ios-config-126="set security-association lifetime seconds 3600"
  ios-config-127="exit"

  %{if var.peer.active_mesh}
    ios-config-130="crypto ikev2 keyring keyring-tun2"
    ios-config-131="peer ${var.peer.ip_ha}"
    ios-config-132="address ${var.peer.ip_ha}"
    ios-config-133="identity address ${aws_eip.eip_ha[0].public_ip}"
    ios-config-134="pre-shared-key ${var.peer.ipsec_key}"
    ios-config-135="exit"
    ios-config-136="exit"

    ios-config-140="crypto ikev2 profile ikev2-prof-tun2"
    ios-config-141="match identity remote address ${var.peer.ip_ha} 255.255.255.255"
    ios-config-142="identity local address ${aws_eip.eip_ha[0].public_ip}"
    ios-config-143="authentication remote pre-share"
    ios-config-144="authentication local pre-share"
    ios-config-145="keyring local keyring-tun2"
    ios-config-146="lifetime 28800"
    ios-config-147="dpd 10 3 periodic"
    ios-config-148="exit"

    ios-config-150="crypto ipsec profile ipsec-prof-tun2"
    ios-config-151="set security-association lifetime seconds 3600"
    ios-config-152="set transform-set ipsec-ts-${var.peer.name}"
    ios-config-153="set pfs group14"
    ios-config-154="set ikev2-profile ikev2-prof-tun2"
    ios-config-155="set security-association lifetime kilobytes disable"
    ios-config-156="set security-association lifetime seconds 3600"
    ios-config-157="exit"
  %{ endif }

  ios-config-160="interface Tunnel 1"
  ios-config-161="ip address ${format("%s %s", cidrhost(var.peer.tun1_prefix_ha, 1), cidrnetmask(var.peer.tun1_prefix_ha))}"
  ios-config-162="ip mtu 1436"
  ios-config-163="ip tcp adjust-mss 1387"
  ios-config-164="tunnel source GigabitEthernet1"
  ios-config-165="tunnel mode ipsec ipv4"
  ios-config-166="tunnel protection ipsec profile ipsec-prof-tun1"
  %{if var.peer.active_mesh}
    ios-config-167="tunnel destination ${var.peer.ip}"
  %{ endif }
  %{if !var.peer.active_mesh && var.peer.enable_ha}
    ios-config-167="tunnel destination ${var.peer.ip_ha}"
  %{ endif }
  ios-config-168="ip virtual-reassembly"
  ios-config-169="exit"

  %{if var.peer.active_mesh}
    ios-config-170="interface Tunnel 2"
    ios-config-171="ip address ${format("%s %s", cidrhost(var.peer.tun2_prefix_ha, 1), cidrnetmask(var.peer.tun2_prefix_ha))}"
    ios-config-172="ip mtu 1436"
    ios-config-173="ip tcp adjust-mss 1387"
    ios-config-174="tunnel source GigabitEthernet1"
    ios-config-175="tunnel mode ipsec ipv4"
    ios-config-176="tunnel protection ipsec profile ipsec-prof-tun2"
    ios-config-177="tunnel destination ${var.peer.ip_ha}"
    ios-config-178="ip virtual-reassembly"
    ios-config-179="exit"
  %{ endif }

  ios-config-180="interface GigabitEthernet2"
  ios-config-181="ip address dhcp"
  ios-config-182="ip nat outside"
  ios-config-183="negotiation auto"
  ios-config-184="no shutdown"
  ios-config-185="exit"

  %{ if var.peer.bgp_asn != null }
    ios-config-200="router bgp ${var.remote_bgp_asn}"
    ios-config-201="bgp log-neighbor-changes"
    ios-config-210="neighbor ${cidrhost(var.peer.tun1_prefix_ha, 2)} remote-as ${var.peer.bgp_asn}"
    ios-config-211="neighbor ${cidrhost(var.peer.tun1_prefix_ha, 2)} timers 50 180"
    %{if var.peer.active_mesh}
      ios-config-212="neighbor ${cidrhost(var.peer.tun2_prefix_ha, 2)} remote-as ${var.peer.bgp_asn}"
      ios-config-213="neighbor ${cidrhost(var.peer.tun2_prefix_ha, 2)} timers 50 180"
    %{ endif }
    ios-config-220="address-family ipv4 unicast"
    ios-config-221="redistribute connected"
    ios-config-222="maximum-paths 2"
    ios-config-223="neighbor ${cidrhost(var.peer.tun1_prefix_ha, 2)} activate"
    ios-config-224="neighbor ${cidrhost(var.peer.tun1_prefix_ha, 2)} soft-reconfiguration inbound"
    %{if var.peer.active_mesh}
      ios-config-225="neighbor ${cidrhost(var.peer.tun2_prefix_ha, 2)} activate"
      ios-config-226="neighbor ${cidrhost(var.peer.tun2_prefix_ha, 2)} soft-reconfiguration inbound"
    %{ endif }
    ios-config-227="exit-address-family"
    ios-config-228="exit"
  %{ endif }

  %{ if var.peer.bgp_asn == null }
    ios-config-300="10.0.0.0 255.0.0.0 Tunnel 1"
    ios-config-301="172.16 255.240.0.0 Tunnel 1"
    ios-config-302="192.168.0.0 255.255.0.0 Tunnel 1"
    %{if var.peer.active_mesh}
      ios-config-303="10.0.0.0 255.0.0.0 Tunnel 2"
      ios-config-304="172.16 255.240.0.0 Tunnel 2"
      ios-config-305="192.168.0.0 255.255.0.0 Tunnel 2"
    %{ endif }
  %{ endif }
  EOT

ios_ipsec_pb = <<EOT
  ios-config-001="hostname ${replace(var.name, "/w", "-")}"
  ios-config-002="username ${var.aws_csr_settings.username} privilege 15 password 0 ${var.aws_csr_settings.password}"

  ios-config-010="ip access-list extended vpn"
  ios-config-011="11 permit ip any 10.0.0.0 0.0.0.255"
  ios-config-011="12 permit ip any 172.16.0.0 0.15.255.255"
  ios-config-011="13 permit ip any 192.16.0.0 0.0.255.255"
  ios-config-014="exit"

  ios-config-020="crypto ikev2 proposal ikev2-prop-${var.peer.name}"
  ios-config-021="encryption aes-cbc-256"
  ios-config-022="integrity sha256"
  ios-config-023="group 14"
  ios-config-024="exit"

  ios-config-030="crypto ikev2 policy 1"
  ios-config-031="match fvrf any"
  ios-config-032="proposal ikev2-prop-${var.peer.name}"
  ios-config-033="exit"

  ios-config-040="crypto ipsec transform-set ipsec-ts-${var.peer.name} esp-aes 256 esp-sha256-hmac"
  ios-config-041="mode tunnel"
  ios-config-042="exit"

  ios-config-050="crypto ipsec df-bit clear"

  ios-config-100="crypto ikev2 keyring keyring-${var.peer.name}"
  ios-config-101="peer ${var.peer.ip}"
  ios-config-102="address ${var.peer.ip}"
  ios-config-103="identity address ${aws_eip.eip.public_ip}"
  ios-config-104="pre-shared-key ${var.peer.ipsec_key}"
  ios-config-105="exit"
  ios-config-106="exit"

  ios-config-110="crypto ikev2 profile ikev2-prof-${var.peer.name}"
  ios-config-111="match identity remote address ${var.peer.ip} 255.255.255.255"
  ios-config-112="identity local address ${aws_eip.eip.public_ip}"
  ios-config-113="authentication remote pre-share"
  ios-config-114="authentication local pre-share"
  ios-config-115="keyring local keyring-${var.peer.name}"
  ios-config-116="lifetime 28800"
  ios-config-117="dpd 10 3 periodic"
  ios-config-118="exit"

  ios-config-130="crypto map ${var.peer.name} 10 ipsec-isakmp"
  ios-config-131="set peer 3.210.192.43"
  ios-config-132="set transform-set ipsec-ts-${var.peer.name}"
  ios-config-133="set pfs group14"
  ios-config-134="set ikev2-profile ikev2-prof-${var.peer.name}"
  ios-config-135="set security-association lifetime kilobytes disable"
  ios-config-136="set security-association lifetime seconds 3600"
  ios-config-137="match address vpn"
  ios-config-138="exit"

  ios-config-170="interface GigabitEthernet1"
  ios-config-171="crypto map ${var.peer.name}"
  ios-config-172="exit"

  ios-config-180="interface GigabitEthernet2"
  ios-config-181="ip address dhcp"
  ios-config-182="ip nat outside"
  ios-config-183="negotiation auto"
  ios-config-184="no shutdown"
  ios-config-185="exit"
  EOT

ios_ipsec_pb_ha = <<EOT
  ios-config-001="hostname ${replace(var.name, "/w", "-")}_ha"
  ios-config-002="username ${var.aws_csr_settings.username} privilege 15 password 0 ${var.aws_csr_settings.password}"

  ios-config-010="ip access-list extended vpn"
  ios-config-011="11 permit ip any 10.0.0.0 0.0.0.255"
  ios-config-011="12 permit ip any 172.16.0.0 0.15.255.255"
  ios-config-011="13 permit ip any 192.16.0.0 0.0.255.255"
  ios-config-014="exit"

  ios-config-020="crypto ikev2 proposal ikev2-prop-${var.peer.name}"
  ios-config-021="encryption aes-cbc-256"
  ios-config-022="integrity sha256"
  ios-config-023="group 14"
  ios-config-024="exit"

  ios-config-030="crypto ikev2 policy 1"
  ios-config-031="match fvrf any"
  ios-config-032="proposal ikev2-prop-${var.peer.name}"
  ios-config-033="exit"

  ios-config-040="crypto ipsec transform-set ipsec-ts-${var.peer.name} esp-aes 256 esp-sha256-hmac"
  ios-config-041="mode tunnel"
  ios-config-042="exit"

  ios-config-050="crypto ipsec df-bit clear"

  %{if var.peer.enable_ha}
    ios-config-100="crypto ikev2 keyring keyring-${var.peer.name}"
    ios-config-101="peer ${var.peer.ip_ha}"
    ios-config-102="address ${var.peer.ip_ha}"
    ios-config-103="identity address ${aws_eip.eip_ha[0].public_ip}"
    ios-config-104="pre-shared-key ${var.peer.ipsec_key}"
    ios-config-105="exit"
    ios-config-106="exit"

    ios-config-110="crypto ikev2 profile ikev2-prof-${var.peer.name}"
    ios-config-111="match identity remote address ${var.peer.ip_ha} 255.255.255.255"
    ios-config-112="identity local address ${aws_eip.eip_ha[0].public_ip}"
    ios-config-113="authentication remote pre-share"
    ios-config-114="authentication local pre-share"
    ios-config-115="keyring local keyring-${var.peer.name}"
    ios-config-116="lifetime 28800"
    ios-config-117="dpd 10 3 periodic"
    ios-config-118="exit"
  %{endif}

  ios-config-130="crypto map ${var.peer.name} 10 ipsec-isakmp"
  ios-config-131="set peer 3.210.192.43"
  ios-config-132="set transform-set ipsec-ts-${var.peer.name}"
  ios-config-133="set pfs group14"
  ios-config-134="set ikev2-profile ikev2-prof-${var.peer.name}"
  ios-config-135="set security-association lifetime kilobytes disable"
  ios-config-136="set security-association lifetime seconds 3600"
  ios-config-137="match address vpn"
  ios-config-138="exit"

  ios-config-170="interface GigabitEthernet1"
  ios-config-171="crypto map ${var.peer.name}"
  ios-config-172="exit"

  ios-config-180="interface GigabitEthernet2"
  ios-config-181="ip address dhcp"
  ios-config-182="ip nat outside"
  ios-config-183="negotiation auto"
  ios-config-184="no shutdown"
  ios-config-185="exit"
  EOT

}
