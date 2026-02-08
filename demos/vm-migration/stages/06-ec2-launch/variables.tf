# variables.tf - Input variables for EC2 launch

variable "aws_region" {
  description = "AWS region for the EC2 instance"
  type        = string
  default     = "us-east-1"
}

variable "state_bucket" {
  description = "S3 bucket containing remote state from prior stages"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for the migrated VM"
  type        = string
  default     = "t3.medium"
}

variable "key_pair_name" {
  description = "EC2 key pair name for SSH access (optional)"
  type        = string
  default     = ""
}
