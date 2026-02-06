# outputs.tf - Outputs needed for MGN agent installation and migration

output "aws_region" {
  description = "AWS region where MGN is configured"
  value       = var.aws_region
}

output "vpc_id" {
  description = "VPC ID for migrated instances"
  value       = local.vpc_id
}

output "staging_subnet_id" {
  description = "Subnet ID for MGN staging area"
  value       = local.subnet_id
}

output "replication_security_group_id" {
  description = "Security group ID for replication servers"
  value       = aws_security_group.mgn_replication.id
}

output "migrated_instances_security_group_id" {
  description = "Security group ID for migrated instances"
  value       = aws_security_group.migrated_instances.id
}

# Agent credentials (sensitive)
output "mgn_agent_access_key_id" {
  description = "Access key ID for MGN agent"
  value       = aws_iam_access_key.mgn_agent.id
  sensitive   = true
}

output "mgn_agent_secret_access_key" {
  description = "Secret access key for MGN agent"
  value       = aws_iam_access_key.mgn_agent.secret
  sensitive   = true
}

# Agent installation instructions
output "agent_installation_instructions" {
  description = "Instructions to install MGN agent on Linux source VM"
  value       = <<-EOT

    ============================================================
    MGN Agent Installation Instructions for Linux
    ============================================================

    1. SSH to your source Linux VM on ESXi

    2. Download the MGN agent installer:

       wget -O ./aws-replication-installer-init https://aws-application-migration-service-${var.aws_region}.s3.${var.aws_region}.amazonaws.com/latest/linux/aws-replication-installer-init
       chmod +x aws-replication-installer-init

    3. Run the installer with your credentials:

       sudo ./aws-replication-installer-init \
         --region ${var.aws_region} \
         --aws-access-key-id $(terraform output -raw mgn_agent_access_key_id) \
         --aws-secret-access-key $(terraform output -raw mgn_agent_secret_access_key) \
         --no-prompt

    4. Verify the agent is running:

       sudo systemctl status aws-replication-agent

    5. Check replication status in AWS Console:
       https://${var.aws_region}.console.aws.amazon.com/mgn/home?region=${var.aws_region}#/sourceServers

    ============================================================
    Network Requirements (from source VM):
    - Outbound TCP 443 to mgn.${var.aws_region}.amazonaws.com
    - Outbound TCP 1500 to replication server public IP
    ============================================================

  EOT
}

output "mgn_console_url" {
  description = "URL to MGN console to monitor replication"
  value       = "https://${var.aws_region}.console.aws.amazon.com/mgn/home?region=${var.aws_region}#/sourceServers"
}

output "next_steps" {
  description = "Next steps after AWS setup"
  value       = <<-EOT

    ============================================================
    NEXT STEPS
    ============================================================

    1. Note down the agent credentials:
       terraform output mgn_agent_access_key_id
       terraform output mgn_agent_secret_access_key

    2. Move to 02-esxi-source/ to get VM details and install agent

    3. After agent is installed and replication is complete:
       - Go to MGN console
       - Select your source server
       - Click "Test and Cutover" → "Launch test instance"
       - Verify the test instance works
       - When ready, perform cutover

    If MGN agent doesn't work, use the fallback:
       cd ../03-fallback-vmimport/

  EOT
}
