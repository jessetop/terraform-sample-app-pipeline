# outputs.tf - Exported values from the VM Import stage

output "ami_id" {
  description = "AMI ID of the imported VM image"
  value       = trimspace(data.local_file.ami_id.content)
}
