variable "aws_region" {
  description = "AWS region for the migration landing zone"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "esxi-migration"
}

variable "vpc_cidr" {
  description = "CIDR block for the migration VPC"
  type        = string
  default     = "10.100.0.0/16"
}

variable "subnet_cidr" {
  description = "CIDR block for the migration subnet"
  type        = string
  default     = "10.100.1.0/24"
}
