# providers.tf - vSphere provider for ESXi connection

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    vsphere = {
      source  = "hashicorp/vsphere"
      version = "~> 2.0"
    }
  }
}

# Configure the vSphere Provider for standalone ESXi
# For standalone ESXi (no vCenter), connect directly to the ESXi host
provider "vsphere" {
  vsphere_server       = var.esxi_host
  user                 = var.esxi_username
  password             = var.esxi_password
  allow_unverified_ssl = var.allow_unverified_ssl

  # For standalone ESXi without vCenter
  # The "datacenter" will be "ha-datacenter" by default
}
