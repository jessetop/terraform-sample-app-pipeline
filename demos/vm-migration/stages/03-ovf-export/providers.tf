# providers.tf - Null provider for OVF export via local-exec

terraform {
  required_version = ">= 1.5.0"

  backend "s3" {
    bucket       = "student02-terraform-state-jiyphf"  # <- Replace with your S3 state bucket
    key          = "vm-migration/ovf-export/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }

  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}
