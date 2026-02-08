# main.tf - Upload OVA to S3 using native Terraform
#
# This stage replaces the bash upload script with a single aws_s3_object resource.
# Key teaching moment: Terraform can manage S3 objects natively — no scripts needed.

# =============================================================================
# REMOTE STATE - Read bucket and OVA details from prior stages
# =============================================================================

data "terraform_remote_state" "aws_infra" {
  backend = "s3"
  config = {
    bucket = var.state_bucket
    key    = "vm-migration/aws-infra/terraform.tfstate"
    region = var.aws_region
  }
}

data "terraform_remote_state" "ovf_export" {
  backend = "s3"
  config = {
    bucket = var.state_bucket
    key    = "vm-migration/ovf-export/terraform.tfstate"
    region = var.aws_region
  }
}

locals {
  bucket_name  = data.terraform_remote_state.aws_infra.outputs.bucket_name
  ova_path     = data.terraform_remote_state.ovf_export.outputs.ova_path
  ova_filename = data.terraform_remote_state.ovf_export.outputs.ova_filename
}

# =============================================================================
# S3 UPLOAD - Native Terraform (replaces bash script)
# =============================================================================

resource "aws_s3_object" "ova" {
  bucket = local.bucket_name
  key    = local.ova_filename
  source = local.ova_path
  etag   = filemd5(local.ova_path)
}
