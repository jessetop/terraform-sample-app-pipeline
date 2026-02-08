output "bucket_name" {
  description = "S3 bucket for VM images"
  value       = aws_s3_bucket.vmimport.id
}

output "bucket_arn" {
  description = "S3 bucket ARN"
  value       = aws_s3_bucket.vmimport.arn
}

output "vmimport_role_arn" {
  description = "IAM role ARN for vmimport service"
  value       = aws_iam_role.vmimport.arn
}

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.migration.id
}

output "subnet_id" {
  description = "Subnet ID for migrated instances"
  value       = aws_subnet.migration.id
}

output "security_group_id" {
  description = "Security group ID for migrated instances"
  value       = aws_security_group.migrated_instances.id
}

output "aws_region" {
  description = "AWS region"
  value       = var.aws_region
}
