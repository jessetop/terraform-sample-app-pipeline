# providers.tf - Legacy app setup (creates resources for import lab)
# NOTE: This uses LOCAL state intentionally - simulating infra created
# before Terraform best practices were adopted at the company.

terraform {
  required_version = ">= 1.5.0"

  # No backend block - uses local state to simulate "legacy" deployment
  # that wasn't following remote state best practices

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
      Student = var.student_id
      Purpose = "Legacy app for import lab"
    }
  }
}
