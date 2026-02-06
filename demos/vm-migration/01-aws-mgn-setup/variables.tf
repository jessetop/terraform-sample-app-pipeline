# variables.tf - Input variables for AWS MGN setup

variable "aws_region" {
  description = "AWS region for MGN infrastructure"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name prefix for resources"
  type        = string
  default     = "esxi-migration"
}

# Networking - use existing VPC or create new
variable "use_existing_vpc" {
  description = "Whether to use an existing VPC (true) or create a new one (false)"
  type        = bool
  default     = false
}

variable "existing_vpc_id" {
  description = "ID of existing VPC (required if use_existing_vpc = true)"
  type        = string
  default     = ""
}

variable "existing_subnet_id" {
  description = "ID of existing subnet for staging area (required if use_existing_vpc = true)"
  type        = string
  default     = ""
}

variable "vpc_cidr" {
  description = "CIDR block for new VPC (if creating)"
  type        = string
  default     = "10.100.0.0/16"
}

variable "staging_subnet_cidr" {
  description = "CIDR block for staging subnet (if creating)"
  type        = string
  default     = "10.100.1.0/24"
}

# MGN Configuration
variable "replication_server_instance_type" {
  description = "Instance type for MGN replication servers"
  type        = string
  default     = "t3.small"
}

variable "use_public_ip_for_replication" {
  description = "Whether replication servers should have public IPs (required without VPN)"
  type        = bool
  default     = true
}

variable "ebs_encryption_key_arn" {
  description = "KMS key ARN for EBS encryption (leave empty for AWS managed key)"
  type        = string
  default     = ""
}

variable "bandwidth_throttling" {
  description = "Bandwidth throttling in Mbps (0 = unlimited)"
  type        = number
  default     = 0
}

# Target instance defaults
variable "target_instance_type" {
  description = "Default instance type for migrated instances"
  type        = string
  default     = "t3.medium"
}
