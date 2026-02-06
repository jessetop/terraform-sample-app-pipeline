# variables.tf - Input variables for ESXi source configuration

# ESXi Connection
variable "esxi_host" {
  description = "ESXi host IP address or hostname"
  type        = string
}

variable "esxi_username" {
  description = "ESXi username (usually 'root')"
  type        = string
  default     = "root"
}

variable "esxi_password" {
  description = "ESXi password"
  type        = string
  sensitive   = true
}

variable "allow_unverified_ssl" {
  description = "Allow unverified SSL certificates (for self-signed certs)"
  type        = bool
  default     = true
}

# VM to migrate
variable "vm_name" {
  description = "Name of the VM to migrate"
  type        = string
}

# AWS MGN Configuration (from 01-aws-mgn-setup outputs)
variable "aws_region" {
  description = "AWS region where MGN is configured"
  type        = string
  default     = "us-east-1"
}

variable "mgn_agent_access_key_id" {
  description = "Access key ID for MGN agent (from 01-aws-mgn-setup output)"
  type        = string
  sensitive   = true
}

variable "mgn_agent_secret_access_key" {
  description = "Secret access key for MGN agent (from 01-aws-mgn-setup output)"
  type        = string
  sensitive   = true
}

# SSH access to source VM (for agent installation)
variable "vm_ssh_user" {
  description = "SSH username for the source VM"
  type        = string
  default     = "root"
}

variable "vm_ssh_private_key_path" {
  description = "Path to SSH private key for the source VM (optional - for automated install)"
  type        = string
  default     = ""
}
