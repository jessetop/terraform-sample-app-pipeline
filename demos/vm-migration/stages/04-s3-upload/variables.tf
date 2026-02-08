# variables.tf - Input variables for S3 upload stage

variable "aws_region" {
  description = "AWS region for provider and remote state"
  type        = string
  default     = "us-east-1"
}

variable "state_bucket" {
  description = "S3 bucket containing remote state from prior stages"
  type        = string
}
