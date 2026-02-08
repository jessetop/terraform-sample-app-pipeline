# variables.tf - Input variables for VM Import stage

variable "aws_region" {
  description = "AWS region for the import operation"
  type        = string
  default     = "us-east-1"
}

variable "state_bucket" {
  description = "S3 bucket containing remote state from prior stages"
  type        = string
}

variable "import_description" {
  description = "Description attached to the imported AMI"
  type        = string
  default     = "Imported from ESXi via VM Import/Export"
}

variable "import_license_type" {
  description = "License type for the imported image (AWS or BYOL)"
  type        = string
  default     = "AWS"

  validation {
    condition     = contains(["AWS", "BYOL"], var.import_license_type)
    error_message = "import_license_type must be \"AWS\" or \"BYOL\"."
  }
}
