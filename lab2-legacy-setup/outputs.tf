# outputs.tf - Legacy app resource IDs
# These outputs match the variable order in lab2-import/terraform.tfvars
# for easy copy/paste. (In the real lab, pretend this file doesn't exist!)

output "state_bucket_name" {
  description = "S3 bucket name from Lab 1"
  value       = var.state_bucket_name
}

# Network Layer

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.legacy.id
}

output "subnet_public_a_id" {
  description = "Public subnet A ID"
  value       = aws_subnet.public_a.id
}

output "subnet_public_b_id" {
  description = "Public subnet B ID"
  value       = aws_subnet.public_b.id
}

output "subnet_private_a_id" {
  description = "Private subnet A ID"
  value       = aws_subnet.private_a.id
}

output "subnet_private_b_id" {
  description = "Private subnet B ID"
  value       = aws_subnet.private_b.id
}

output "internet_gateway_id" {
  description = "Internet Gateway ID"
  value       = aws_internet_gateway.legacy.id
}

output "eip_allocation_id" {
  description = "Elastic IP allocation ID for NAT Gateway"
  value       = aws_eip.nat.allocation_id
}

output "nat_gateway_id" {
  description = "NAT Gateway ID"
  value       = aws_nat_gateway.legacy.id
}

output "route_table_public_id" {
  description = "Public route table ID"
  value       = aws_route_table.public.id
}

output "route_table_private_id" {
  description = "Private route table ID"
  value       = aws_route_table.private.id
}

# Security Layer

output "security_group_alb_id" {
  description = "ALB security group ID"
  value       = aws_security_group.alb.id
}

output "security_group_ec2_id" {
  description = "EC2 security group ID"
  value       = aws_security_group.ec2.id
}

# Application Layer

output "alb_arn" {
  description = "ALB ARN"
  value       = aws_lb.legacy.arn
}

output "target_group_arn" {
  description = "Target Group ARN"
  value       = aws_lb_target_group.legacy.arn
}

output "listener_arn" {
  description = "ALB Listener ARN"
  value       = aws_lb_listener.legacy.arn
}

# Compute Layer

output "launch_template_id" {
  description = "Launch Template ID"
  value       = aws_launch_template.legacy.id
}

output "autoscaling_group_name" {
  description = "Auto Scaling Group name"
  value       = aws_autoscaling_group.legacy.name
}

# Utility

output "test_url" {
  description = "URL to test the legacy application"
  value       = "http://${aws_lb.legacy.dns_name}"
}
