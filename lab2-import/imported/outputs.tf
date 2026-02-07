# outputs.tf - Imported infrastructure outputs

output "vpc_id" {
  description = "VPC ID of the imported legacy application"
  value       = aws_vpc.legacy.id
}

output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.legacy.id
}

output "public_ip" {
  description = "Public IP of the legacy server"
  value       = aws_instance.legacy.public_ip
}

output "app_url" {
  description = "Application URL"
  value       = "http://${aws_instance.legacy.public_ip}"
}

output "managed_resource_count" {
  description = "Total number of resources under Terraform management"
  value       = "7 resources imported"
}
