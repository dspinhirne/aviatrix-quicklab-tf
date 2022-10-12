variable "vpc_id" {
  type = string
}

variable "name" {
  type = string
}

variable "peer" {
  type = object({
    name: string
    ip: string
    enable_ha: optional(bool,false)
    ip_ha: optional(string,null)
    ipsec_key: string
    tun1_prefix: optional(string, "169.254.0.248/30")
    tun1_prefix_ha: optional(string, "169.254.0.252/30")
  })
}
