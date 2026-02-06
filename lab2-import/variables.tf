# variables.tf
# Input variables for Lab 2 import

variable "student_id" {
  description = "Your assigned student ID (e.g., student01)"
  type        = string

  validation {
    condition     = can(regex("^student[0-9]{2}$", var.student_id))
    error_message = "Student ID must match the pattern 'studentXX' where XX is a two-digit number (e.g., student01)."
  }
}

# NOTE: This variable is for documentation/reference only.
# The backend block in providers.tf cannot use variables - you must
# manually copy this value into the backend block after Lab 1 is deployed.

variable "state_bucket_name" {
  description = "S3 bucket name from Lab 1 output (e.g., student01-terraform-state-abc123)"
  type        = string

  validation {
    condition     = !can(regex("(SUFFIX|studentXX)", var.state_bucket_name))
    error_message = "Replace placeholder with your actual bucket name from Lab 1 output (terraform output state_bucket_name)."
  }
}

# =============================================================================
# RESOURCE IDs FOR IMPORT
# Discover these using AWS CLI, then paste the values into terraform.tfvars
# =============================================================================

# Network Layer
variable "vpc_id" {
  description = "VPC ID (e.g., vpc-abc123)"
  type        = string
}

variable "subnet_public_a_id" {
  description = "Public subnet A ID (e.g., subnet-abc123)"
  type        = string
}

variable "subnet_public_b_id" {
  description = "Public subnet B ID (e.g., subnet-def456)"
  type        = string
}

variable "subnet_private_a_id" {
  description = "Private subnet A ID (e.g., subnet-ghi789)"
  type        = string
}

variable "subnet_private_b_id" {
  description = "Private subnet B ID (e.g., subnet-jkl012)"
  type        = string
}

variable "internet_gateway_id" {
  description = "Internet Gateway ID (e.g., igw-abc123)"
  type        = string
}

variable "eip_allocation_id" {
  description = "Elastic IP allocation ID for NAT Gateway (e.g., eipalloc-abc123)"
  type        = string
}

variable "nat_gateway_id" {
  description = "NAT Gateway ID (e.g., nat-abc123)"
  type        = string
}

variable "route_table_public_id" {
  description = "Public route table ID (e.g., rtb-abc123)"
  type        = string
}

variable "route_table_private_id" {
  description = "Private route table ID (e.g., rtb-def456)"
  type        = string
}

# Security Layer
variable "security_group_alb_id" {
  description = "ALB security group ID (e.g., sg-abc123)"
  type        = string
}

variable "security_group_ec2_id" {
  description = "EC2 security group ID (e.g., sg-def456)"
  type        = string
}

# Application Layer
variable "alb_arn" {
  description = "ALB ARN"
  type        = string
}

variable "target_group_arn" {
  description = "Target Group ARN"
  type        = string
}

variable "listener_arn" {
  description = "ALB Listener ARN"
  type        = string
}

# Compute Layer
variable "launch_template_id" {
  description = "Launch Template ID (e.g., lt-abc123)"
  type        = string
}

variable "autoscaling_group_name" {
  description = "Auto Scaling Group name (e.g., student01-legacy-asg)"
  type        = string
}
