# outputs.tf - EC2 instance outputs

output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.migrated.id
}

output "public_ip" {
  description = "Public IP address (Elastic IP)"
  value       = aws_eip.migrated.public_ip
}

output "public_dns" {
  description = "Public DNS name"
  value       = aws_eip.migrated.public_dns
}

output "ssh_command" {
  description = "SSH command to connect to the migrated instance"
  value       = "ssh ec2-user@${aws_eip.migrated.public_ip}"
}
