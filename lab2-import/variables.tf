# variables.tf
# Input variables for Lab 2 import (simplified architecture)

variable "student_id" {
  description = "Your assigned student ID (e.g., student01)"
  type        = string

  validation {
    condition     = can(regex("^student[0-9]{2}$", var.student_id))
    error_message = "Student ID must match the pattern 'studentXX' where XX is a two-digit number (e.g., student01)."
  }
}

variable "state_bucket_name" {
  description = "S3 bucket name from Lab 1 output (e.g., student01-terraform-state-abc123)"
  type        = string

  validation {
    condition     = !can(regex("(SUFFIX|studentXX)", var.state_bucket_name))
    error_message = "Replace placeholder with your actual bucket name from Lab 1 output (terraform output state_bucket_name)."
  }
}

# =============================================================================
# RESOURCE IDs FOR IMPORT (6 resources)
# Get these from: cd ../lab2-legacy-setup && terraform output
# =============================================================================

# Network Layer

variable "vpc_id" {
  description = "VPC ID (e.g., vpc-abc123)"
  type        = string
}

variable "subnet_id" {
  description = "Public subnet ID (e.g., subnet-abc123)"
  type        = string
}

variable "internet_gateway_id" {
  description = "Internet Gateway ID (e.g., igw-abc123)"
  type        = string
}

variable "route_table_id" {
  description = "Route table ID (e.g., rtb-abc123)"
  type        = string
}

# Security Layer

variable "security_group_id" {
  description = "Security group ID (e.g., sg-abc123)"
  type        = string
}

# Compute Layer

variable "instance_id" {
  description = "EC2 instance ID (e.g., i-abc123)"
  type        = string
}
