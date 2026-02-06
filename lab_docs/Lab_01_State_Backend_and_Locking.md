# Lab 1: State Backend Setup & Locking

*Terraform Day 3: Enterprise Deployment & Operations*

| | |
|---|---|
| **Course** | Terraform on AWS (300-Level) |
| **Module** | Enterprise State Management |
| **Duration** | 60 minutes |
| **Difficulty** | Advanced |
| **Prerequisites** | Terraform Days 1-2, AWS Console access, Terraform CLI installed |

---

## Lab Overview

### Narrative

Last Friday at NovaTech Solutions, two platform engineers -- Priya and Marcus -- both ran `terraform apply` against the same environment within seconds of each other. Marcus's apply overwrote Priya's newly-added security group rules for the payments API. For eleven minutes, production traffic was exposed on ports that should have been locked down.

Jordan, NovaTech's Platform Engineering lead, has issued a mandate: **no more local state files**. Every Terraform project must use remote state stored in S3, encrypted at rest, versioned for rollback capability, and protected by state locking so that two engineers can never simultaneously modify the same infrastructure.

Your task: build the state infrastructure that will become the backbone of all of NovaTech's Terraform operations.

### Learning Objectives

By the end of this lab, you will be able to:

1. Deploy an S3 bucket with versioning, encryption, and public access blocking for Terraform state storage
2. Migrate an existing Terraform project from local state to a remote S3 backend
3. Demonstrate and explain state locking behavior using S3 native locking
4. Design a state path naming convention that isolates environments, teams, and services

---

## Architecture Overview

```
+------------------------------------------------------------------+
|                        AWS Account                                |
|                                                                   |
|  +---------------------------+                                    |
|  |  S3 Bucket                |                                    |
|  |  studentXX-terraform-     |                                    |
|  |  state-SUFFIX             |                                    |
|  |                           |                                    |
|  |  - Versioning: Enabled    |     S3 Native Locking              |
|  |  - Encryption: AES256     |     (use_lockfile = true)          |
|  |  - Public Access: Blocked |                                    |
|  |                           |              |                     |
|  |  State File Paths:        |     +--------+--------+            |
|  |  +-----------------------+|     |                 |            |
|  |  | platform/state-infra/ ||     v                 v            |
|  |  |   terraform.tfstate   ||  +---------+    +---------+        |
|  |  +-----------------------+|  | Engr. 1 |    | Engr. 2 |        |
|  |  | staging/demo-app/     ||  | Terminal|    | Terminal|        |
|  |  |   terraform.tfstate   ||  +----+----+    +----+----+        |
|  |  +-----------------------+|       |              |             |
|  |  | prod/payments-api/    ||       |  Lock Held   | BLOCKED     |
|  |  |   terraform.tfstate   ||       +--------------+             |
|  |  +-----------------------+|                                    |
|  +---------------------------+                                    |
|                                                                   |
+------------------------------------------------------------------+
```

### Key Concepts

| Concept | Definition |
|---|---|
| **Remote State** | Terraform state stored in a shared, durable location (S3) rather than locally. Enables team collaboration. |
| **State Locking** | A mechanism that prevents concurrent writes. S3 native locking uses conditional writes on a `.tflock` file. |
| **State Encryption** | Server-side encryption (AES256) applied to state files at rest. State files contain sensitive data. |
| **State Versioning** | S3 bucket versioning preserves every previous version of the state file, enabling rollback. |
| **Bootstrap Problem** | The state infrastructure must be created before any project can use remote state. Initial deployment uses local state. |

---

## Part A: Deploy State Infrastructure (20 min)

In this section you will create the S3 bucket that will store all of NovaTech's Terraform state.

### Step 1: Navigate to the Lab Directory

```bash
cd lab1-state-infra
```

### Step 2: Review the Configuration Files

The lab files are pre-created. Review each file to understand the configuration:

| File | Purpose |
|------|---------|
| `providers.tf` | AWS provider configuration with default tags |
| `main.tf` | S3 bucket with versioning, encryption, public access block, and locking demo resources |
| `variables.tf` | Input variable for student ID with validation |
| `outputs.tf` | Outputs the bucket name for use in other labs |
| `terraform.tfvars` | Your student ID (needs to be updated) |

### Step 3: Update Your Student ID

Edit `terraform.tfvars` and replace `studentXX` with your assigned student ID:

```hcl
student_id = "student01"  # Use your actual student ID
```

### Step 4: Initialize and Apply

```bash
terraform init
terraform plan
terraform apply
```

When prompted, type `yes` and press Enter.

**Expected output:**

```
Apply complete! Resources: 5 added, 0 changed, 0 destroyed.

Outputs:

state_bucket_name = "student01-terraform-state-abc123"
```

> **Note:** The random suffix ensures globally unique bucket names. Record your actual bucket name -- you will need it for the backend configuration.

### Step 5: Verify in AWS

```bash
# Verify bucket exists (use your actual bucket name from terraform output)
aws s3api head-bucket --bucket $(terraform output -raw state_bucket_name)

# Verify versioning is enabled
aws s3api get-bucket-versioning --bucket $(terraform output -raw state_bucket_name)

# Verify encryption
aws s3api get-bucket-encryption --bucket $(terraform output -raw state_bucket_name)
```

---

## Part B: Migrate to Remote State (15 min)

Your state infrastructure is deployed, but its own state is stored locally. Now migrate that local state into the S3 bucket.

### Step 6: Confirm Local State Exists

```bash
ls -la terraform.tfstate
terraform state list
```

You should see 5+ resources tracked in local state.

### Step 7: Add Backend Configuration

Edit `providers.tf` and uncomment the backend block. Update the bucket name with your actual value from `terraform output state_bucket_name`:

```hcl
backend "s3" {
  bucket       = "student01-terraform-state-abc123"  # Your actual bucket name
  key          = "platform/state-infra/terraform.tfstate"
  region       = "us-east-1"
  encrypt      = true
  use_lockfile = true  # S3 native locking
}
```

> **Note:** We use `use_lockfile = true` for S3 native locking instead of DynamoDB. This is the modern approach that eliminates the need for a separate DynamoDB table.

### Step 8: Run `terraform init` to Trigger Migration

```bash
terraform init
```

Terraform detects existing local state and prompts for migration. Type `yes`.

**Expected output:**

```
Successfully configured the backend "s3"! Terraform will automatically
use this backend unless the backend configuration changes.
```

### Step 9: Verify State File in S3

```bash
aws s3 ls s3://$(terraform output -raw state_bucket_name)/platform/state-infra/
```

You should see `terraform.tfstate` in the output.

### Step 10: Verify Remote State Works

```bash
terraform state list
terraform plan
```

The plan should show "No changes" -- your state is now remote.

---

## Part C: State Locking in Action (15 min)

Prove that S3 native locking prevents concurrent modifications.

### Step 11: Open Two Terminal Windows

In **both terminals**, navigate to `lab1-state-infra`:

```bash
cd lab1-state-infra
```

### Step 12: Trigger a Lock Conflict

**Terminal 1** - Start an apply (the `time_sleep` resource takes 30 seconds):

```bash
terraform apply -auto-approve
```

**Terminal 2** - Immediately try to run a plan:

```bash
terraform plan
```

### Step 13: Observe the Lock Error

Terminal 2 will show:

```
╷
│ Error: Error acquiring the state lock
│
│ Error message: operation error S3: PutObject, https response error
│ StatusCode: 412, Precondition Failed
│ ...
│ Terraform acquires a state lock to protect the state from being written
│ by multiple users at the same time.
╵
```

> **What happened?** Terminal 1 acquired an exclusive lock by creating a `.tflock` file in S3. Terminal 2's attempt to acquire the same lock failed because S3 conditional writes prevent overwriting an existing lock file.

### Step 14: View the Lock File

While Terminal 1 is still running:

```bash
aws s3 ls s3://$(terraform output -raw state_bucket_name)/platform/state-infra/
```

You'll see both `terraform.tfstate` and `terraform.tfstate.tflock`.

### Step 15: Wait and Retry

After Terminal 1 completes, the lock is released. Retry in Terminal 2:

```bash
terraform plan
```

It succeeds because the lock was released.

---

## Part D: Multi-Environment State Paths (10 min)

Demonstrate environment isolation using different state paths.

### Step 16: Navigate to the Demo App

```bash
cd ../staging-demo-app
```

### Step 17: Update Configuration

Edit `terraform.tfvars` with your student ID.

Edit `providers.tf` and update the bucket name to match your Lab 1 output.

### Step 18: Deploy

```bash
terraform init
terraform apply
```

### Step 19: Verify Both State Files Exist

```bash
aws s3 ls s3://YOUR-BUCKET-NAME/ --recursive
```

You should see two state files:

```
platform/state-infra/terraform.tfstate
platform/staging/demo-app/terraform.tfstate
```

### NovaTech's State Path Convention

```
{team}/{service}/{environment}/terraform.tfstate
```

Example structure:

```
s3://studentXX-terraform-state-SUFFIX/
├── platform/
│   ├── state-infra/terraform.tfstate
│   └── networking/
│       ├── dev/terraform.tfstate
│       ├── staging/terraform.tfstate
│       └── prod/terraform.tfstate
├── payments/
│   └── payments-api/
│       ├── dev/terraform.tfstate
│       ├── staging/terraform.tfstate
│       └── prod/terraform.tfstate
└── checkout/
    └── cart-service/
        └── ...
```

---

## Troubleshooting

### S3 Bucket Name Already Exists

S3 bucket names are globally unique. If you get this error, the random suffix should prevent collisions, but you may need to destroy and re-apply to generate a new suffix.

### Backend Configuration Changed Error

```bash
terraform init -reconfigure
```

### Permission Denied

Verify your AWS credentials:

```bash
aws sts get-caller-identity
```

### Stuck Lock

If a lock is stuck (engineer's laptop crashed mid-apply):

```bash
# View the lock file
aws s3 ls s3://BUCKET/path/to/terraform.tfstate.tflock

# Remove it (ONLY if you're certain no apply is running)
aws s3 rm s3://BUCKET/path/to/terraform.tfstate.tflock
```

> **WARNING:** Only remove a lock when you are **certain** no Terraform operation is in progress.

---

## Lab Completion Checklist

- [ ] Deployed S3 bucket with versioning, encryption, and public access blocked
- [ ] Migrated local state to S3 backend
- [ ] Demonstrated state locking by triggering concurrent access error
- [ ] Created second project with different state path
- [ ] Verified both state files exist in S3

---

## Cost Considerations

| Resource | Cost |
|---|---|
| S3 Bucket | ~$0.00 (state files are typically < 50 KB) |
| S3 Requests | ~$0.00 (< 100 requests per lab) |
| SSM Parameters | Free (standard tier) |

**Estimated total: < $0.01**

> **Note:** Do not destroy the S3 bucket after this lab. It will be used in Labs 2, 3, and 4.

---

## Next Steps

In **Lab 2: Import Legacy Application**, you will:

- Discover pre-existing AWS infrastructure deployed "manually"
- Use Terraform import blocks to bring resources under management
- Store the imported state in the S3 backend you just built
