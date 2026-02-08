# providers.tf - AWS provider configuration for MGN setup

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = "vm-migration-demo"
      ManagedBy = "Terraform"
      Purpose   = "ESXi-to-AWS-Migration"
    }
  }
}
