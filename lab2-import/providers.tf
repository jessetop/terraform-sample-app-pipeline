# providers.tf - Backend and provider configuration
# Uses the S3 backend created in Lab 1

terraform {
  required_version = ">= 1.5.0"

  # IMPORTANT: Replace the bucket value below with your actual value from Lab 1.
  # Run `terraform output` in lab1-state-infra/ to get your state_bucket_name.
  backend "s3" {
    bucket       = "studentXX-terraform-state-SUFFIX"  # <- Replace with your state_bucket_name from Lab 1
    key          = "import/legacy-app/terraform.tfstate"
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
      Student   = "studentXX"
      ManagedBy = "Terraform"
    }
  }
}
