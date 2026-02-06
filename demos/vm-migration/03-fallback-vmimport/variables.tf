# variables.tf - Input variables for VM Import fallback

variable "aws_region" {
  description = "AWS region for import"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name prefix for resources"
  type        = string
  default     = "esxi-migration"
}

# S3 bucket for OVA/VMDK uploads
variable "import_bucket_name" {
  description = "S3 bucket name for VM images (leave empty for auto-generated)"
  type        = string
  default     = ""
}

# ESXi information (for export scripts)
variable "esxi_host" {
  description = "ESXi host IP address"
  type        = string
}

variable "esxi_username" {
  description = "ESXi username"
  type        = string
  default     = "root"
}

variable "esxi_password" {
  description = "ESXi password"
  type        = string
  sensitive   = true
}

variable "vm_name" {
  description = "Name of the VM to export and import"
  type        = string
}

variable "datastore_name" {
  description = "ESXi datastore name (default: datastore1)"
  type        = string
  default     = "datastore1"
}

# Import configuration
variable "import_description" {
  description = "Description for the imported AMI"
  type        = string
  default     = "Imported from ESXi"
}

variable "import_license_type" {
  description = "License type: AWS (use AWS license) or BYOL (bring your own)"
  type        = string
  default     = "AWS"

  validation {
    condition     = contains(["AWS", "BYOL"], var.import_license_type)
    error_message = "License type must be 'AWS' or 'BYOL'."
  }
}

# Target instance configuration (for optional launch)
variable "launch_instance" {
  description = "Whether to launch an instance from the imported AMI"
  type        = bool
  default     = false
}

variable "instance_type" {
  description = "Instance type for launched instance"
  type        = string
  default     = "t3.medium"
}

variable "subnet_id" {
  description = "Subnet ID for launched instance (required if launch_instance = true)"
  type        = string
  default     = ""
}

variable "key_pair_name" {
  description = "EC2 key pair name for SSH access (required if launch_instance = true)"
  type        = string
  default     = ""
}
