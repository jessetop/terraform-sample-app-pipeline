# Lab 1: State Backend Setup & Locking - Complete Solution

This repository contains the complete solution code for **Lab 1: State Backend Setup & Locking** from Terraform Day 3.

## Overview

This lab demonstrates enterprise-grade Terraform state management:
- Remote state storage in S3 with versioning and encryption
- State locking using DynamoDB to prevent concurrent modifications
- Multi-environment state isolation using different S3 key paths
- Migration from local to remote state

## Directory Structure

```
.
├── lab1-state-infra/          # Main state infrastructure (Part A & B)
│   ├── providers.tf           # AWS provider and backend configuration
│   ├── main.tf               # S3 bucket, DynamoDB table, locking demo
│   ├── outputs.tf            # Bucket/table names and backend config
│   ├── terraform.tfvars      # Student ID variable
│   └── README.md             # Deployment instructions
│
├── staging-demo-app/          # Demo app for state isolation (Part D)
│   ├── providers.tf          # AWS provider with different state key
│   ├── main.tf              # SSM parameters for demo app
│   ├── terraform.tfvars     # Student ID variable
│   └── README.md            # Deployment instructions
│
└── README.md                 # This file
```

## Quick Start

### Prerequisites

- AWS CLI configured with valid credentials
- Terraform >= 1.5.0 installed
- Assigned student ID (e.g., `student01`, `student14`)

### Step 1: Deploy State Infrastructure

```bash
cd lab1-state-infra

# Update terraform.tfvars with your student ID
# student_id = "student01"

terraform init
terraform apply
```

This creates:
- S3 bucket: `studentXX-terraform-state`
- DynamoDB table: `studentXX-terraform-lock`
- SSM parameter for locking demo

### Step 2: Migrate to Remote State

```bash
# Uncomment the backend block in providers.tf (lines 7-13)
# Update studentXX to your actual student ID

terraform init
# Type 'yes' when prompted to migrate state

# Verify migration
aws s3 ls s3://studentXX-terraform-state/platform/state-infra/
terraform state list
```

### Step 3: Test State Locking

Open two terminals in the `lab1-state-infra` directory:

**Terminal 1:**
```bash
terraform apply -auto-approve
```

**Terminal 2 (immediately):**
```bash
terraform plan  # Should show lock error
```

View the lock:
```bash
aws dynamodb scan --table-name studentXX-terraform-lock
```

### Step 4: Deploy Demo App (State Isolation)

```bash
cd ../staging-demo-app

# Update terraform.tfvars and providers.tf with your student ID

terraform init
terraform apply

# Verify both state files exist
aws s3 ls s3://studentXX-terraform-state/ --recursive
```

## Lab Components

### Part A: Deploy State Infrastructure (20 min)
- Create S3 bucket with versioning, encryption, and public access blocking
- Create DynamoDB table for state locking
- Deploy using local state (bootstrap problem)

### Part B: Migrate to Remote State (20 min)
- Add backend configuration to providers.tf
- Migrate local state to S3
- Verify remote state operations

### Part C: State Locking in Action (20 min)
- Add time_sleep resource for locking demo
- Trigger concurrent access to demonstrate locking
- View lock records in DynamoDB
- Understand force-unlock command

### Part D: Multi-Environment State Paths (15 min)
- Create second project with different state key
- Demonstrate state isolation
- Understand NovaTech's naming convention

## Resources Created

### State Infrastructure
| Resource | Name | Purpose |
|----------|------|---------|
| S3 Bucket | `studentXX-terraform-state` | State file storage |
| S3 Versioning | Enabled | State file history |
| S3 Encryption | AES256 | Security at rest |
| S3 Public Block | All blocked | Prevent public access |
| DynamoDB Table | `studentXX-terraform-lock` | State locking |
| SSM Parameter | `/studentXX/lab1/lock-demo` | Locking demo |

### Demo App
| Resource | Name | Purpose |
|----------|------|---------|
| SSM Parameter | `/studentXX/staging/demo-app/config` | App config |
| SSM Parameter | `/studentXX/staging/demo-app/feature-flags` | Feature flags |

## State File Organization

```
s3://studentXX-terraform-state/
├── platform/
│   ├── state-infra/
│   │   └── terraform.tfstate          # State infrastructure's own state
│   └── staging/
│       └── demo-app/
│           └── terraform.tfstate      # Demo app state
```

## Important Notes

1. **Replace `studentXX`** with your actual student ID in ALL files:
   - `terraform.tfvars` in both directories
   - `providers.tf` backend blocks
   - `providers.tf` default tags

2. **Backend block is commented out initially** in `lab1-state-infra/providers.tf`
   - This allows bootstrap deployment with local state
   - Uncomment after initial deployment to migrate to remote state

3. **Do NOT destroy these resources** after completing the lab
   - They are required for Labs 2, 3, and 4
   - Cleanup instructions provided at end of Lab 4

4. **State locking is automatic**
   - Terraform acquires lock before any state-modifying operation
   - Lock is released automatically after operation completes
   - Use `force-unlock` only when absolutely certain no operation is running

## Verification Commands

```bash
# Verify S3 bucket configuration
aws s3api head-bucket --bucket studentXX-terraform-state
aws s3api get-bucket-versioning --bucket studentXX-terraform-state
aws s3api get-bucket-encryption --bucket studentXX-terraform-state
aws s3api get-public-access-block --bucket studentXX-terraform-state

# Verify DynamoDB table
aws dynamodb describe-table --table-name studentXX-terraform-lock

# List all state files
aws s3 ls s3://studentXX-terraform-state/ --recursive

# View state contents (lab only - avoid in production)
aws s3 cp s3://studentXX-terraform-state/platform/state-infra/terraform.tfstate - | python3 -m json.tool | head -20

# Check Terraform state
terraform state list
terraform state show aws_s3_bucket.terraform_state
terraform plan  # Should show "No changes"
```

## Troubleshooting

### Bucket Already Exists
```bash
# Import existing bucket instead of creating new one
terraform import aws_s3_bucket.terraform_state studentXX-terraform-state
```

### Backend Configuration Changed
```bash
# Re-initialize with reconfigure flag
terraform init -reconfigure
```

### Stuck Lock
```bash
# Verify no Terraform processes running
ps aux | grep terraform

# Check lock age in DynamoDB
aws dynamodb scan --table-name studentXX-terraform-lock

# Force unlock (use with extreme caution)
terraform force-unlock <LOCK_ID>
```

### Permission Denied
```bash
# Verify AWS credentials
aws sts get-caller-identity

# Verify bucket access
aws s3 ls s3://studentXX-terraform-state/

# Verify DynamoDB access
aws dynamodb describe-table --table-name studentXX-terraform-lock
```

## Cost Estimate

All resources cost less than **$0.01** for the entire lab:
- S3 storage: ~$0.00 (state files are KB-sized)
- S3 requests: ~$0.00 (< 50 requests)
- DynamoDB: ~$0.00 (PAY_PER_REQUEST with minimal operations)
- SSM Parameters: Free (standard tier, up to 10,000 per account)

## Learning Objectives Achieved

✅ Deploy S3 bucket with versioning, encryption, and public access blocking  
✅ Deploy DynamoDB table for state locking  
✅ Migrate from local to remote state  
✅ Demonstrate state locking with concurrent access  
✅ Design multi-environment state path convention  
✅ Use `terraform state` commands with remote state  
✅ Understand force-unlock and when to use it  

## Next Steps

Proceed to **Lab 2: Import Legacy Application** where you will:
- Import pre-existing AWS infrastructure into Terraform
- Use the state backend created in this lab
- Apply NovaTech's state path naming convention
- Achieve drift-free infrastructure management

## Additional Resources

- [Terraform S3 Backend Documentation](https://developer.hashicorp.com/terraform/language/settings/backends/s3)
- [Terraform State Locking](https://developer.hashicorp.com/terraform/language/state/locking)
- [AWS S3 Bucket Versioning](https://docs.aws.amazon.com/AmazonS3/latest/userguide/Versioning.html)
- [AWS DynamoDB Conditional Writes](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/Expressions.ConditionExpressions.html)
