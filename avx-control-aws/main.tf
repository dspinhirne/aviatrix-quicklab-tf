data "aws_availability_zones" "available" {
  state = "available"
}

module "aviatrix-iam-roles-aws" {
  count = var.create_iam_roles ? 1:0
  source        = "github.com/AviatrixSystems/terraform-aviatrix-aws-controller/modules/aviatrix-controller-iam-roles"
}

module "aviatrix-controller-build-aws" {
  source                 = "github.com/AviatrixSystems/terraform-aviatrix-aws-controller/modules/aviatrix-controller-build"
  type = var.controller_license_type
  availability_zone = data.aws_availability_zones.available.names[0]
  use_existing_keypair = true
  key_pair_name = var.keypair
  termination_protection = var.termination_protection
  incoming_ssl_cidrs = var.permitted_prefixes
  name_prefix = var.name_prefix
}

module "aviatrix-controller-initialize-aws" {
  source                 = "github.com/AviatrixSystems/terraform-aviatrix-aws-controller/modules/aviatrix-controller-initialize"
  admin_email         = var.admin_email
  admin_password      = var.admin_password
  controller_version  = var.controller_version
  customer_license_id = var.controller_license
  private_ip          = module.aviatrix-controller-build-aws.private_ip
  public_ip           = module.aviatrix-controller-build-aws.public_ip
  access_account_name = var.access_account_name
  access_account_email = var.admin_email
  aws_account_id = var.access_account_id
}

module "copilot_build_aws" {
  source                = "github.com/AviatrixSystems/terraform-modules-copilot.git//copilot_build_aws"
  count = var.deploy_copilot ? 1:0
  use_existing_keypair = true
  keypair               = var.keypair
  controller_public_ip  = module.aviatrix-controller-build-aws.public_ip
  controller_private_ip = module.aviatrix-controller-build-aws.private_ip
  name_prefix = var.name_prefix
  
  allowed_cidrs = {
    "tcp_cidrs" = {
      protocol = "tcp"
      port     = "443"
      cidrs    = var.permitted_prefixes
    }
    "udp_cidrs_1" = {
      protocol = "udp"
      port     = "5000"
      cidrs    = ["0.0.0.0/0"]
    }
    "udp_cidrs_2" = {
      protocol = "udp"
      port     = "31283"
      cidrs    = ["0.0.0.0/0"]
    }
  }
}