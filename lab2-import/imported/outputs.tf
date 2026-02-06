# outputs.tf - Imported infrastructure outputs

output "vpc_id" {
  description = "VPC ID of the imported legacy application"
  value       = aws_vpc.legacy.id
}

output "alb_dns_name" {
  description = "DNS name of the legacy application load balancer"
  value       = aws_lb.legacy.dns_name
}

output "alb_url" {
  description = "Application URL"
  value       = "http://${aws_lb.legacy.dns_name}"
}

output "asg_name" {
  description = "Auto Scaling Group name"
  value       = aws_autoscaling_group.legacy.name
}

output "managed_resource_count" {
  description = "Total number of resources under Terraform management"
  value       = "21 resources imported"
}
