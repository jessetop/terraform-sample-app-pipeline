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
    command = <<-EOT
      set -e

      echo "=============================================="
      echo "Starting VM Import"
      echo "Source: s3://${local.s3_bucket}/${local.s3_key}"
      echo "Region: ${local.region}"
      echo "=============================================="

      # Start import task
      IMPORT_TASK_ID=$(aws ec2 import-image \
        --region "${local.region}" \
        --description "${var.import_description}" \
        --license-type "${var.import_license_type}" \
        --disk-containers "Description=VM Import,Format=ova,UserBucket={S3Bucket=${local.s3_bucket},S3Key=${local.s3_key}}" \
        --query 'ImportTaskId' \
        --output text)

      echo "Import task: $IMPORT_TASK_ID"
      echo ""

      # Poll for completion
      while true; do
        STATUS=$(aws ec2 describe-import-image-tasks \
          --region "${local.region}" \
          --import-task-ids "$IMPORT_TASK_ID" \
          --query 'ImportImageTasks[0].[Status,StatusMessage,Progress]' \
          --output text)

        STATE=$(echo "$STATUS" | awk '{print $1}')
        MESSAGE=$(echo "$STATUS" | awk '{$1=""; $NF=""; print}' | xargs)
        PROGRESS=$(echo "$STATUS" | awk '{print $NF}')

        echo "$(date '+%H:%M:%S') | $STATE | $PROGRESS% | $MESSAGE"

        if [ "$STATE" = "completed" ]; then
          AMI_ID=$(aws ec2 describe-import-image-tasks \
            --region "${local.region}" \
            --import-task-ids "$IMPORT_TASK_ID" \
            --query 'ImportImageTasks[0].ImageId' \
            --output text)

          echo ""
          echo "Import complete! AMI: $AMI_ID"
          echo -n "$AMI_ID" > "${path.module}/ami_id.txt"
          break
        fi

        if [ "$STATE" = "deleted" ] || [ "$STATE" = "failed" ]; then
          echo "ERROR: Import failed!"
          aws ec2 describe-import-image-tasks \
            --region "${local.region}" \
            --import-task-ids "$IMPORT_TASK_ID"
          exit 1
        fi

        sleep 30
      done
    EOT
  }
}

# Read the AMI ID back into Terraform state
data "local_file" "ami_id" {
  filename   = "${path.module}/ami_id.txt"
  depends_on = [null_resource.vm_import]
}
