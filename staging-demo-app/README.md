# Staging Demo App - Solution

This directory demonstrates multi-environment state isolation using different S3 key paths.

## Purpose

This is a second Terraform project that:
- Uses the **same** S3 bucket and DynamoDB table as the state infrastructure
- Uses a **different** state file path: `platform/staging/demo-app/terraform.tfstate`
- Demonstrates that multiple projects can safely share backend infrastructure

## Deployment

1. **Ensure the state infrastructure is deployed first** (from `lab1-state-infra/`)

2. **Update your student ID** in `terraform.tfvars`:
   ```hcl
   student_id = "student01"  # Replace with your actual ID
   ```

3. **Update the backend configuration** in `providers.tf`:
   - Replace `studentXX` with your actual student ID in the `bucket` and `dynamodb_table` values

4. **Deploy**:
   ```bash
   terraform init
   terraform apply
   ```

## Resources Created

| Resource | Name | Purpose |
|----------|------|---------|
| SSM Parameter | `/studentXX/staging/demo-app/config` | Application configuration |
| SSM Parameter | `/studentXX/staging/demo-app/feature-flags` | Feature flags |

## State Isolation

After deployment, verify both state files exist independently:

```bash
# List all state files in the bucket
aws s3 ls s3://studentXX-terraform-state/ --recursive

# Expected output:
# platform/state-infra/terraform.tfstate
# platform/staging/demo-app/terraform.tfstate
```

Each project tracks different resources:

```bash
# From lab1-state-infra directory
cd ../lab1-state-infra
terraform state list
# Shows: S3 bucket, DynamoDB table, SSM lock-demo parameter, etc.

# From staging-demo-app directory
cd ../staging-demo-app
terraform state list
# Shows: Only the two SSM parameters for this app
```

## Key Concepts Demonstrated

1. **Shared Backend Infrastructure**: Both projects use the same S3 bucket and DynamoDB table
2. **State Isolation**: Different `key` paths keep state files completely separate
3. **Independent Locking**: Each project gets its own lock (LockID = full S3 key path)
4. **Concurrent Operations**: Both projects can apply simultaneously without conflict

## NovaTech State Path Convention

This follows NovaTech's naming convention:
```
{team}/{service}/{environment}/terraform.tfstate
```

Example:
- `platform/state-infra/terraform.tfstate` - Management infrastructure
- `platform/staging/demo-app/terraform.tfstate` - This demo app
- `payments/payments-api/prod/terraform.tfstate` - Production payments API
- `checkout/cart-service/dev/terraform.tfstate` - Dev cart service
