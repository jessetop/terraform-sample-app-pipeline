# variables.tf - Input variables for legacy app setup

variable "student_id" {
  description = "Your assigned student ID (e.g., student01)"
  type        = string

  validation {
    condition     = can(regex("^student[0-9]{2}$", var.student_id))
    error_message = "Student ID must match the pattern 'studentXX' where XX is a two-digit number (e.g., student01)."
  }
}

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "instance_type" {
  description = "EC2 instance type for ASG"
  type        = string
  default     = "t3.micro"
}

# =============================================================================
# Lab 1 State Backend (for convenience - passed through to outputs)
# =============================================================================

variable "state_bucket_name" {
  description = "S3 bucket name from Lab 1 (for reference in outputs)"
  type        = string
  default     = ""
}
