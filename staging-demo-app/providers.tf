# providers.tf
# Staging demo app -- uses the SAME S3 bucket but a DIFFERENT key path

terraform {
  required_version = ">= 1.5.0"

  # IMPORTANT: Replace the bucket value below with your actual value from Lab 1.
  # Run `terraform output` in lab1-state-infra/ to get your state_bucket_name.
  #
  # Example: If your Lab 1 output shows:
  #   state_bucket_name = "student01-terraform-state-abc123"
  #
  # Then update the bucket line below accordingly.
  backend "s3" {
    bucket       = "studentXX-terraform-state-SUFFIX"  # <- Replace with your state_bucket_name from Lab 1
    key          = "platform/staging/demo-app/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true  # Uses S3 native locking instead of DynamoDB
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      Student     = "studentXX"
      Project     = "demo-app"
      Environment = "staging"
      ManagedBy   = "Terraform"
      Lab         = "day3-lab1"
    }
  }
}
