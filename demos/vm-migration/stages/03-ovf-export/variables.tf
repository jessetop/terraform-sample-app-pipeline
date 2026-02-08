# variables.tf - Input variables for OVF export stage

variable "state_bucket" {
  description = "S3 bucket containing remote state from prior stages"
  type        = string
}

variable "esxi_username" {
  description = "ESXi username for ovftool authentication"
  type        = string
  default     = "root"
}

variable "esxi_password" {
  description = "ESXi password (not stored in remote state for security)"
  type        = string
  sensitive   = true
}

variable "export_dir" {
  description = "Local directory to store exported OVA file"
  type        = string
  default     = "./exported"
}
