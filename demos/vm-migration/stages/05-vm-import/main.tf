# main.tf - Convert OVA to AMI using AWS VM Import/Export
#
# This stage uses local-exec because no Terraform resource exists for the
# async VM Import/Export API. The script starts the import, polls for
# completion, and writes the resulting AMI ID to a local file.

# =============================================================================
# REMOTE STATE - Read S3 location from prior stages
# =============================================================================

data "terraform_remote_state" "aws_infra" {
  backend = "s3"
  config = {
    bucket = var.state_bucket
    key    = "vm-migration/aws-infra/terraform.tfstate"
    region = var.aws_region
  }
}

data "terraform_remote_state" "s3_upload" {
  backend = "s3"
  config = {
    bucket = var.state_bucket
    key    = "vm-migration/s3-upload/terraform.tfstate"
    region = var.aws_region
  }
}

locals {
  s3_bucket = data.terraform_remote_state.s3_upload.outputs.s3_bucket
  s3_key    = data.terraform_remote_state.s3_upload.outputs.s3_key
  region    = data.terraform_remote_state.aws_infra.outputs.aws_region
}

# =============================================================================
# VM IMPORT - Start import and poll for AMI ID
# =============================================================================

resource "null_resource" "vm_import" {
  triggers = {
    s3_uri = "s3://${local.s3_bucket}/${local.s3_key}"
    etag   = data.terraform_remote_state.s3_upload.outputs.etag
  }

  provisioner "local-exec" {
    interpreter = ["wsl", "bash", "-c"]
    command = "${path.module}/import-vm.sh '${local.s3_bucket}' '${local.s3_key}' '${local.region}' '${var.import_description}' '${var.import_license_type}' '${path.module}/ami_id.txt'"
  }
}

# Read the AMI ID back into Terraform state
data "local_file" "ami_id" {
  filename   = "${path.module}/ami_id.txt"
  depends_on = [null_resource.vm_import]
}
