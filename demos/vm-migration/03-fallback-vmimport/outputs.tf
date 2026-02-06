# outputs.tf - VM Import outputs and instructions

output "s3_bucket_name" {
  description = "S3 bucket for VM images"
  value       = aws_s3_bucket.vmimport.id
}

output "s3_bucket_arn" {
  description = "S3 bucket ARN"
  value       = aws_s3_bucket.vmimport.arn
}

output "vmimport_role_arn" {
  description = "IAM role ARN for vmimport service"
  value       = aws_iam_role.vmimport.arn
}

output "export_script" {
  description = "Path to the VM export script"
  value       = local_file.export_script.filename
}

output "upload_script" {
  description = "Path to the S3 upload script"
  value       = local_file.upload_script.filename
}

output "import_script" {
  description = "Path to the import script"
  value       = local_file.import_script.filename
}

output "instructions" {
  description = "Step-by-step instructions for VM import"
  value       = <<-EOT

    ============================================================
    VM Import Instructions (Fallback Method)
    ============================================================

    This method exports your ESXi VM to OVA, uploads to S3, and
    converts it to an AMI using AWS VM Import/Export.

    PREREQUISITES:
    -------------
    1. ovftool installed on your workstation
       Download: https://developer.vmware.com/web/tool/ovf/

    2. AWS CLI configured with credentials

    3. The source VM should be powered OFF for a clean export
       (or use a snapshot)

    STEP 1: Export VM from ESXi
    ---------------------------
    Power off the VM first, then:

    export ESXI_PASSWORD='your-esxi-password'
    ./scripts/export-vm-generated.sh

    This creates: ./exported/${var.vm_name}.ova

    STEP 2: Upload to S3
    --------------------
    ./scripts/upload-to-s3-generated.sh

    This uploads to: s3://${aws_s3_bucket.vmimport.id}/${var.vm_name}.ova

    STEP 3: Import as AMI
    ---------------------
    ./scripts/import-image-generated.sh

    This starts the import job and monitors progress.
    Import can take 20-60+ minutes depending on disk size.

    STEP 4: Launch Instance (optional)
    ----------------------------------
    After import completes, you'll get an AMI ID. Launch with:

    aws ec2 run-instances \
      --image-id ami-xxxxxxxxx \
      --instance-type t3.medium \
      --subnet-id subnet-xxxxxxxxx \
      --key-name your-key-pair \
      --security-group-ids ${var.launch_instance ? aws_security_group.imported_vm[0].id : "sg-xxxxxxxxx"}

    TROUBLESHOOTING:
    ----------------
    Check import status:
      aws ec2 describe-import-image-tasks --region ${var.aws_region}

    Common issues:
    - "ClientError: Disk validation failed" - Check disk format
    - "Access Denied" - Verify vmimport role permissions
    - Slow upload - Use AWS CLI multipart (automatic for large files)

    CLEANUP:
    --------
    1. Delete uploaded OVA from S3:
       aws s3 rm s3://${aws_s3_bucket.vmimport.id}/${var.vm_name}.ova

    2. Deregister AMI and delete snapshots (if not needed):
       aws ec2 deregister-image --image-id ami-xxxxxxxxx
       aws ec2 delete-snapshot --snapshot-id snap-xxxxxxxxx

    3. Destroy Terraform resources:
       terraform destroy

  EOT
}

output "s3_upload_command" {
  description = "Manual S3 upload command"
  value       = "aws s3 cp ./exported/${var.vm_name}.ova s3://${aws_s3_bucket.vmimport.id}/${var.vm_name}.ova --region ${var.aws_region}"
}

output "check_import_status_command" {
  description = "Command to check import task status"
  value       = "aws ec2 describe-import-image-tasks --region ${var.aws_region}"
}
