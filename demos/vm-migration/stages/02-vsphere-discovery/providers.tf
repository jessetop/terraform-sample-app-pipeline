# providers.tf - vSphere provider for ESXi source VM discovery

terraform {
  required_version = ">= 1.5.0"

  backend "s3" {
    bucket       = "YOUR-STATE-BUCKET-NAME"  # <- Replace with your S3 state bucket
    key          = "vm-migration/vsphere-discovery/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }

  required_providers {
    vsphere = {
      source  = "hashicorp/vsphere"
      version = "~> 2.0"
    }
  }
}

provider "vsphere" {
  vsphere_server       = var.esxi_host
  user                 = var.esxi_username
  password             = var.esxi_password
  allow_unverified_ssl = var.allow_unverified_ssl
}
