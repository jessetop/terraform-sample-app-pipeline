# providers.tf - AWS and Null providers for VM Import

terraform {
  required_version = ">= 1.5.0"

  backend "s3" {
    bucket       = "YOUR-STATE-BUCKET-NAME"  # <- Replace with your S3 state bucket
    key          = "vm-migration/vm-import/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
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
