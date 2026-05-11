# variables.tf
# Input variables for Lab 1 state infrastructure

variable "student_id" {
  description = "Your assigned student ID (e.g., student01) — used for state bucket naming"
  type        = string

  validation {
    condition     = can(regex("^student[0-9]{2}$", var.student_id))
    error_message = "Student ID must match the pattern 'studentXX' where XX is a two-digit number."
  }
}

variable "account" {
  description = "Student account identifier for app-config naming (typically the same as student_id)."
  type        = string
  default     = ""
}

variable "region" {
  description = "AWS region for resources (e.g., us-east-2)."
  type        = string
  default     = "us-east-2"
}

variable "state_bucket_name" {
  description = <<-EOT
    S3 bucket name containing the lab1-networking remote state.
    Set this after lab1-networking has been deployed once and you have
    captured the output 'state_bucket_name'. Pass as `-var
    state_bucket_name=<name>` or set in terraform.tfvars.
  EOT
  type        = string
  default     = ""
}

# ============================================================================
# Workspace-aware configuration
# ============================================================================
# This locals block illustrates how `terraform.workspace` lets one
# configuration serve multiple environments. Switch workspaces and the
# values change automatically. Subsequent labs and modules reference
# `local.config.instance_type`, `local.config.min_size`, etc.
# ----------------------------------------------------------------------------

locals {
  # Environment-specific settings keyed by workspace name
  environment_config = {
    dev = {
      instance_type = "t3.micro"
      min_size      = 1
      max_size      = 2
    }
    staging = {
      instance_type = "t3.small"
      min_size      = 2
      max_size      = 4
    }
    prod = {
      instance_type = "t3.medium"
      min_size      = 3
      max_size      = 10
    }
  }

  # Select config for current workspace. Falls back to dev if workspace
  # is not one of the three defined above (avoids a plan-time error
  # before Part B's workspace_guard.tf is in place).
  config = lookup(local.environment_config, terraform.workspace, local.environment_config.dev)
}
