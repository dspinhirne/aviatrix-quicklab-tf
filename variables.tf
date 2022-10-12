# Permitted access to instances
variable "permitted_prefixes" {
  type = list(string)
}

# Cloud Service Provider Accounts
variable "csps" {
  type = object({
    aws: optional(object({
      account: string
      region: string
    }),null)
    azure: optional(object({
      account: string
      region: string
      sub_id: string
      dir_id: string
      app_id: string
      app_key: string
    }),null)
  })
}

# Aviatrix Default Gateway Sizes
variable "gw_sizes" {
  type = object({
    aws: optional(object({
      sm: string
      lg: string
    }), {sm: "t3.small", lg: "c5.xlarge"})
    azure: optional(object({
      sm: string
      lg: string
    }), {sm: "Standard_B1ms", lg: "Standard_B1ms"})
  })
  default = {}
}

# AWS cisco csr settings
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

# avx transit gateway definitions
variable "transits" {
  type = map(object({
    disabled: optional(bool, false)
    csp: string
    prefix: string
    size: optional(string, null)
    hpe: optional(bool, false)
    enable_ha: optional(bool, false)
    bgp_asn: optional(string, null)
    enable_transit_firenet: optional(bool, false)
    enable_segmentation: optional(bool, false)
  }))
  default = {}
}

# avx spoke gateway definitions
variable "spokes" {
  type = map(object({
    disabled: optional(bool, false)
    csp: string
    prefix: string
    size: optional(string, null)
    hpe: optional(bool, false)
    enable_ha: optional(bool, false)
    enable_bgp: optional(bool, false)
    bgp_asn: optional(string, null)
  }))
  default = {}
}

# avx transit gateway peering
variable "transit_peerings" {
  type = list(object({
    peer1: string
    peer2: string
  }))
  default = []
}

# avx spoke to transit attachments
variable "spoke_transit_attachments" {
    type = list(object({
      spoke: string
      transit: string
    }))
    default = []
}

# avx network network segmentation
variable "net_seg_domains" {
  type = list(string)
  default = []
}
variable "net_seg_connection_policies" {
  type = list(object({
    d1: string
    d2: string
  }))
  default = []
}
variable "net_seg_associations" {
    type = map(object({
      transit = string
      spoke = string
    }))
    default = {}
}

# avx external connections
variable "external_connections" {
  type = map(object({
    disabled: optional(bool, false)
    gw_type: string
    gw_name: string
    local_bgp_asn: optional(number,null)
    external_peer: object({
      type: string
      prefix: string
      bgp_asn: optional(number,null)
    })
    gre_only: optional(bool, false)
    tun1_prefix: optional(string, "169.254.0.240/30")
    tun2_prefix: optional(string, "169.254.0.244/30")
    tun1_prefix_ha: optional(string,"169.254.0.248/30")
    tun2_prefix_ha: optional(string,"169.254.0.252/30")
  }))
  default = {}
}

# Site to Cloud
variable "s2c" {
  type = map(object({
    disabled: optional(bool, false)
    gw_type: string
    gw_name: string
    external_peer: object({
      type: string
      prefix: string
    })
    tun1_prefix: optional(string, "169.254.0.248/30")
    tun1_prefix_ha: optional(string,"169.254.0.252/30")
    unmapped: optional(object({
      cloud_prefix: string
      site_prefix: string
    }),null)
    mapped: optional(object({
      cloud_prefix: string
      site_prefix: string
      cloud_virtual: string
      site_virtual: string
    }),null)
  }))
  default = {}
}

