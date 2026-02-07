# terraform.tfvars
# Replace studentXX with your assigned student ID
# Replace SUFFIX with the random suffix from your Lab 1 terraform output

student_id = "studentXX"

# This value comes from Lab 1 output. After running `terraform apply` in
# lab1-state-infra, run `terraform output` to get your actual value.
# Then update BOTH this file AND the backend block in providers.tf.

state_bucket_name = "studentXX-terraform-state-SUFFIX"

# =============================================================================
# RESOURCE IDs FOR IMPORT (6 resources)
# Get these from: cd ../lab2-legacy-setup && terraform output
# =============================================================================

# Network Layer
vpc_id              = "vpc-REPLACE_ME"
subnet_id           = "subnet-REPLACE_ME"
internet_gateway_id = "igw-REPLACE_ME"
route_table_id      = "rtb-REPLACE_ME"

# Security Layer
security_group_id   = "sg-REPLACE_ME"

# Compute Layer
instance_id         = "i-REPLACE_ME"
