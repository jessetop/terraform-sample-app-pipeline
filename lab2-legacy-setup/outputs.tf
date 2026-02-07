# outputs.tf - Legacy app resource IDs (simplified)
# These outputs provide the resource IDs needed for Lab 2 import.
# (In the real lab, pretend this file doesn't exist!)

output "state_bucket_name" {
  description = "S3 bucket name from Lab 1"
  value       = var.state_bucket_name
}

# Network Layer

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.legacy.id
}

output "subnet_id" {
  description = "Public subnet ID"
  value       = aws_subnet.public.id
}

output "internet_gateway_id" {
  description = "Internet Gateway ID"
  value       = aws_internet_gateway.legacy.id
}

output "route_table_id" {
  description = "Route table ID"
  value       = aws_route_table.public.id
}

# Security Layer

output "security_group_id" {
  description = "Security group ID"
  value       = aws_security_group.legacy.id
}

# Compute Layer

output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.legacy.id
}

# Utility

output "app_url" {
  description = "URL to test the legacy application"
  value       = "http://${aws_instance.legacy.public_ip}"
}

output "public_ip" {
  description = "Public IP of the legacy server"
  value       = aws_instance.legacy.public_ip
}
