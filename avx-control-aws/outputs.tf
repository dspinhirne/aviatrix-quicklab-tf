output "exports" {
  value = <<EOT
export AVIATRIX_CONTROLLER_IP=${module.aviatrix-controller-build-aws.public_ip}
export AVIATRIX_USERNAME=admin
export AVIATRIX_PASSWORD=${var.admin_password}
EOT
}

