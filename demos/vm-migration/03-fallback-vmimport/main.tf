# main.tf - VM Import infrastructure (fallback when MGN doesn't work)
#
# This configuration sets up:
# 1. S3 bucket for OVA/VMDK uploads
# 2. IAM role for vmimport service
# 3. Scripts for export, upload, and import

locals {
  bucket_name = var.import_bucket_name != "" ? var.import_bucket_name : "${var.project_name}-vmimport-${random_string.suffix.result}"
}

resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

# =============================================================================
# S3 BUCKET FOR VM IMAGES
# =============================================================================

resource "aws_s3_bucket" "vmimport" {
  bucket = local.bucket_name

  tags = {
    Name = local.bucket_name
  }
}

resource "aws_s3_bucket_versioning" "vmimport" {
  bucket = aws_s3_bucket.vmimport.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "vmimport" {
  bucket = aws_s3_bucket.vmimport.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "vmimport" {
  bucket = aws_s3_bucket.vmimport.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# =============================================================================
# IAM ROLE FOR VMIMPORT SERVICE
# =============================================================================

# The vmimport service role - allows AWS VM Import service to access S3 and EC2
resource "aws_iam_role" "vmimport" {
  name = "${var.project_name}-vmimport-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "vmie.amazonaws.com"
        }
        Condition = {
          StringEquals = {
            "sts:ExternalId" = "vmimport"
          }
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-vmimport-role"
  }
}

resource "aws_iam_role_policy" "vmimport" {
  name = "${var.project_name}-vmimport-policy"
  role = aws_iam_role.vmimport.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3Access"
        Effect = "Allow"
        Action = [
          "s3:GetBucketLocation",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:PutObject",
          "s3:GetBucketAcl"
        ]
        Resource = [
          aws_s3_bucket.vmimport.arn,
          "${aws_s3_bucket.vmimport.arn}/*"
        ]
      },
      {
        Sid    = "EC2Access"
        Effect = "Allow"
        Action = [
          "ec2:ModifySnapshotAttribute",
          "ec2:CopySnapshot",
          "ec2:RegisterImage",
          "ec2:Describe*"
        ]
        Resource = "*"
      },
      {
        Sid    = "KMSAccess"
        Effect = "Allow"
        Action = [
          "kms:CreateGrant",
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:Encrypt",
          "kms:GenerateDataKey*",
          "kms:ReEncrypt*"
        ]
        Resource = "*"
      },
      {
        Sid    = "LicenseManager"
        Effect = "Allow"
        Action = [
          "license-manager:GetLicenseConfiguration",
          "license-manager:UpdateLicenseSpecificationsForResource",
          "license-manager:ListLicenseSpecificationsForResource"
        ]
        Resource = "*"
      }
    ]
  })
}

# =============================================================================
# GENERATE SCRIPTS
# =============================================================================

# Script to export VM from ESXi
resource "local_file" "export_script" {
  filename        = "${path.module}/scripts/export-vm-generated.sh"
  file_permission = "0755"
  content         = <<-EOT
    #!/bin/bash
    # export-vm-generated.sh - Export VM from ESXi using ovftool
    #
    # Prerequisites:
    # - ovftool installed (download from VMware)
    # - Network access to ESXi host

    set -e

    ESXI_HOST="${var.esxi_host}"
    ESXI_USER="${var.esxi_username}"
    VM_NAME="${var.vm_name}"
    DATASTORE="${var.datastore_name}"
    OUTPUT_DIR="./exported"

    echo "=============================================="
    echo "VM Export from ESXi"
    echo "=============================================="
    echo "Host: $ESXI_HOST"
    echo "VM: $VM_NAME"
    echo ""

    # Check ovftool
    if ! command -v ovftool &> /dev/null; then
        echo "ERROR: ovftool not found"
        echo "Download from: https://developer.vmware.com/web/tool/ovf/"
        exit 1
    fi

    # Create output directory
    mkdir -p "$OUTPUT_DIR"

    # Prompt for password if not provided
    if [ -z "$ESXI_PASSWORD" ]; then
        echo -n "Enter ESXi password for $ESXI_USER: "
        read -s ESXI_PASSWORD
        echo ""
    fi

    echo "Exporting VM to OVA..."
    echo "(This may take a while for large VMs)"
    echo ""

    # Export using ovftool
    # Note: VM must be powered off for clean export
    ovftool \
        --noSSLVerify \
        --diskMode=thin \
        "vi://$ESXI_USER:$ESXI_PASSWORD@$ESXI_HOST/$VM_NAME" \
        "$OUTPUT_DIR/$VM_NAME.ova"

    echo ""
    echo "=============================================="
    echo "Export Complete!"
    echo "=============================================="
    echo "Output: $OUTPUT_DIR/$VM_NAME.ova"
    echo ""
    echo "Next step: Upload to S3"
    echo "  ./scripts/upload-to-s3-generated.sh"
  EOT
}

# Script to upload OVA to S3
resource "local_file" "upload_script" {
  filename        = "${path.module}/scripts/upload-to-s3-generated.sh"
  file_permission = "0755"
  content         = <<-EOT
    #!/bin/bash
    # upload-to-s3-generated.sh - Upload exported OVA to S3

    set -e

    BUCKET="${aws_s3_bucket.vmimport.id}"
    REGION="${var.aws_region}"
    VM_NAME="${var.vm_name}"
    OVA_FILE="./exported/$VM_NAME.ova"

    echo "=============================================="
    echo "Upload OVA to S3"
    echo "=============================================="
    echo "Bucket: $BUCKET"
    echo "File: $OVA_FILE"
    echo ""

    if [ ! -f "$OVA_FILE" ]; then
        echo "ERROR: OVA file not found: $OVA_FILE"
        echo "Run export-vm-generated.sh first"
        exit 1
    fi

    FILE_SIZE=$(du -h "$OVA_FILE" | cut -f1)
    echo "File size: $FILE_SIZE"
    echo ""
    echo "Uploading... (this may take a while for large files)"
    echo ""

    # Upload with multipart for large files
    aws s3 cp "$OVA_FILE" "s3://$BUCKET/$VM_NAME.ova" \
        --region "$REGION"

    echo ""
    echo "=============================================="
    echo "Upload Complete!"
    echo "=============================================="
    echo "S3 URI: s3://$BUCKET/$VM_NAME.ova"
    echo ""
    echo "Next step: Import image"
    echo "  ./scripts/import-image-generated.sh"
  EOT
}

# Script to trigger vm-import
resource "local_file" "import_script" {
  filename        = "${path.module}/scripts/import-image-generated.sh"
  file_permission = "0755"
  content         = <<-EOT
    #!/bin/bash
    # import-image-generated.sh - Import OVA as AMI using VM Import/Export

    set -e

    BUCKET="${aws_s3_bucket.vmimport.id}"
    REGION="${var.aws_region}"
    VM_NAME="${var.vm_name}"
    DESCRIPTION="${var.import_description}"
    LICENSE_TYPE="${var.import_license_type}"

    echo "=============================================="
    echo "Import VM Image to AMI"
    echo "=============================================="
    echo "Source: s3://$BUCKET/$VM_NAME.ova"
    echo "Region: $REGION"
    echo "License: $LICENSE_TYPE"
    echo ""

    # Create import task
    IMPORT_TASK_ID=$(aws ec2 import-image \
        --region "$REGION" \
        --description "$DESCRIPTION - $VM_NAME" \
        --license-type "$LICENSE_TYPE" \
        --disk-containers "Description=$VM_NAME,Format=ova,UserBucket={S3Bucket=$BUCKET,S3Key=$VM_NAME.ova}" \
        --query 'ImportTaskId' \
        --output text)

    echo "Import task started: $IMPORT_TASK_ID"
    echo ""
    echo "=============================================="
    echo "Monitoring Import Progress"
    echo "=============================================="
    echo ""

    # Monitor progress
    while true; do
        STATUS=$(aws ec2 describe-import-image-tasks \
            --region "$REGION" \
            --import-task-ids "$IMPORT_TASK_ID" \
            --query 'ImportImageTasks[0].[Status,StatusMessage,Progress]' \
            --output text)

        STATE=$(echo "$STATUS" | awk '{print $1}')
        MESSAGE=$(echo "$STATUS" | awk '{print $2}')
        PROGRESS=$(echo "$STATUS" | awk '{print $3}')

        echo "$(date '+%H:%M:%S') - Status: $STATE | Progress: $PROGRESS% | $MESSAGE"

        if [ "$STATE" = "completed" ]; then
            echo ""
            echo "=============================================="
            echo "Import Complete!"
            echo "=============================================="

            AMI_ID=$(aws ec2 describe-import-image-tasks \
                --region "$REGION" \
                --import-task-ids "$IMPORT_TASK_ID" \
                --query 'ImportImageTasks[0].ImageId' \
                --output text)

            echo "AMI ID: $AMI_ID"
            echo ""
            echo "You can now launch an instance:"
            echo "  aws ec2 run-instances --image-id $AMI_ID --instance-type t3.medium ..."
            echo ""
            echo "Or use Terraform to launch (set launch_instance = true)"
            break
        elif [ "$STATE" = "deleted" ] || [ "$STATE" = "failed" ]; then
            echo ""
            echo "ERROR: Import failed!"
            echo "Check task details:"
            echo "  aws ec2 describe-import-image-tasks --import-task-ids $IMPORT_TASK_ID"
            exit 1
        fi

        sleep 30
    done
  EOT
}

# =============================================================================
# OPTIONAL: LAUNCH INSTANCE FROM IMPORTED AMI
# =============================================================================

# Note: This requires the AMI to be created first via the import script
# Set launch_instance = true and provide ami_id after import completes

# Security group for launched instance
resource "aws_security_group" "imported_vm" {
  count = var.launch_instance ? 1 : 0

  name        = "${var.project_name}-imported-vm-sg"
  description = "Security group for imported VM"
  vpc_id      = data.aws_subnet.selected[0].vpc_id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-imported-vm-sg"
  }
}

data "aws_subnet" "selected" {
  count = var.launch_instance ? 1 : 0
  id    = var.subnet_id
}
