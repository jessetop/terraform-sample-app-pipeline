# Lab 2: Import Legacy Application

*Terraform Day 3: Enterprise Deployment & Operations*

| | |
|---|---|
| **Course** | Terraform on AWS (300-Level) |
| **Module** | Terraform Import |
| **Duration** | 45 minutes |
| **Difficulty** | Intermediate |
| **Prerequisites** | Lab 1 completed, Legacy app deployed by instructor |
| **Terraform** | >= 1.5.0 (import blocks + config generation) |

---

## Lab Overview

### Narrative

NovaTech's "Customer Portal" application was deployed two years ago by an engineer who has since left the company. The application was built entirely through the AWS Console -- click by click -- with no infrastructure-as-code, no version history, and no reproducible deployment process. It runs as a simple single-server web application: an EC2 instance running Apache httpd in a public subnet.

The application serves internal users and must remain running during the import process.

Last week, SOC 2 auditors flagged the Customer Portal as "unmanaged infrastructure" -- a compliance finding that must be remediated before the next audit cycle. Jordan, your team lead, assigns you the task: bring the application under Terraform management without any downtime. No rebuilding, no replacing -- you must adopt the existing resources exactly as they are.

**Future Evolution:** After successfully importing this single-server legacy app, you could evolve it to a production-ready architecture by adding load balancing, auto scaling, and multi-AZ redundancy -- all without recreating the original imported resources.

### Learning Objectives

By the end of this lab, you will:

- Discover existing AWS resources using terraform outputs (or AWS CLI in real scenarios)
- Write import blocks for a complete application stack
- Use `terraform plan -generate-config-out` to auto-generate HCL configuration
- Clean up generated configuration by removing computed attributes
- Achieve a clean `terraform plan` showing zero changes
- Add `lifecycle { prevent_destroy = true }` to protect critical resources

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    VPC: 10.0.0.0/16                             │
│                    studentXX-legacy-vpc                         │
│                                                                 │
│   ┌─────────────────────────────────────────────────────────┐   │
│   │              Public Subnet (AZ-a)                       │   │
│   │                 10.0.1.0/24                             │   │
│   │                                                         │   │
│   │   ┌─────────────────────────────────────────────────┐   │   │
│   │   │              EC2 Instance                       │   │   │
│   │   │              studentXX-legacy-server            │   │   │
│   │   │                                                 │   │   │
│   │   │   ┌─────────────────────────────────────────┐   │   │   │
│   │   │   │  Apache httpd                           │   │   │   │
│   │   │   │  "Legacy Application"                   │   │   │   │
│   │   │   │  Port 80                                │   │   │   │
│   │   │   └─────────────────────────────────────────┘   │   │   │
│   │   │                                                 │   │   │
│   │   │  Security Group: HTTP (80), SSH (22)            │   │   │
│   │   └─────────────────────────────────────────────────┘   │   │
│   │                                                         │   │
│   └─────────────────────────────────────────────────────────┘   │
│                              │                                   │
│   ┌──────────────────────────┴───────────────────────────────┐  │
│   │                    Route Table                            │  │
│   │                 0.0.0.0/0 → IGW                           │  │
│   └──────────────────────────────────────────────────────────┘  │
│                              │                                   │
│   ┌──────────────────────────┴───────────────────────────────┐  │
│   │                 Internet Gateway                          │  │
│   │                 studentXX-legacy-igw                      │  │
│   └──────────────────────────┬───────────────────────────────┘  │
│                              │                                   │
└──────────────────────────────┼───────────────────────────────────┘
                               │
                           Internet
```

### Resources to Import (7 total)

| # | Resource Type | Name Pattern | ID Format |
|---|---------------|--------------|-----------|
| 1 | VPC | `studentXX-legacy-vpc` | `vpc-xxxxxxxxx` |
| 2 | Public Subnet | `studentXX-legacy-public` | `subnet-xxxxxxxxx` |
| 3 | Internet Gateway | `studentXX-legacy-igw` | `igw-xxxxxxxxx` |
| 4 | Route Table | `studentXX-legacy-rt` | `rtb-xxxxxxxxx` |
| 5 | Route Table Association | -- | `subnet-xxx/rtb-xxx` |
| 6 | Security Group | `studentXX-legacy-sg` | `sg-xxxxxxxxx` |
| 7 | EC2 Instance | `studentXX-legacy-server` | `i-xxxxxxxxx` |

Replace `studentXX` with your assigned student ID throughout this lab.

---

## Part A: Resource Discovery (10 min)

### Step 1: Navigate to Working Directory

```bash
cd ~/terraform-day3/lab2-import
```

### Step 2: Get Resource IDs from Legacy Setup

Since the legacy infrastructure was deployed using Terraform in `lab2-legacy-setup`, all resource IDs are available as outputs:

```bash
cd ../lab2-legacy-setup
terraform output
```

You should see output like:
```
app_url = "http://54.xxx.xxx.xxx"
instance_id = "i-0abc123def456"
internet_gateway_id = "igw-0abc123def456"
public_ip = "54.xxx.xxx.xxx"
route_table_id = "rtb-0abc123def456"
security_group_id = "sg-0abc123def456"
state_bucket_name = "student01-terraform-state-abc123"
subnet_id = "subnet-0abc123def456"
vpc_id = "vpc-0abc123def456"
```

> **Real-World Note:** In a real engagement with console-created infrastructure, you would discover each resource using AWS CLI commands. See Appendix A for example discovery commands.

### Step 3: Verify the Application is Running

```bash
# Get the public IP from the output above, or:
PUBLIC_IP=$(cd ../lab2-legacy-setup && terraform output -raw public_ip)
curl -s "http://${PUBLIC_IP}" | head -10
```

You should see the legacy application HTML. The application must remain running throughout this lab.

### Step 4: Return to Import Directory

```bash
cd ~/terraform-day3/lab2-import
```

---

## Part B: Configure Import (10 min)

### Step 5: Update terraform.tfvars

Edit `terraform.tfvars` and paste the resource IDs from the terraform output:

```hcl
# terraform.tfvars

student_id        = "student01"                           # Your student ID
state_bucket_name = "student01-terraform-state-abc123"    # From Lab 1

# Resource IDs from: cd ../lab2-legacy-setup && terraform output
vpc_id              = "vpc-0abc123def456"
subnet_id           = "subnet-0abc123def456"
internet_gateway_id = "igw-0abc123def456"
route_table_id      = "rtb-0abc123def456"
security_group_id   = "sg-0abc123def456"
instance_id         = "i-0abc123def456"
```

### Step 6: Update providers.tf Backend

Edit `providers.tf` and update the S3 backend bucket name:

```hcl
backend "s3" {
  bucket       = "student01-terraform-state-abc123"  # Your bucket from Lab 1
  key          = "import/legacy-app/terraform.tfstate"
  region       = "us-east-1"
  encrypt      = true
  use_lockfile = true
}
```

### Step 7: Review imports.tf

The import blocks are already configured to use variables. Review the file:

```bash
cat imports.tf
```

You should see 7 import blocks, one for each resource:
- `aws_vpc.legacy`
- `aws_subnet.public`
- `aws_internet_gateway.legacy`
- `aws_route_table.public`
- `aws_route_table_association.public`
- `aws_security_group.legacy`
- `aws_instance.legacy`

---

## Part C: Generate Configuration (10 min)

### Step 8: Initialize Terraform

```bash
terraform init
```

### Step 9: Generate Configuration

Run plan with config generation:

```bash
terraform plan -generate-config-out=generated.tf
```

Terraform will:
1. Read each import block
2. Query AWS for the live resource state
3. Write HCL configuration to `generated.tf`

You should see output like:
```
aws_vpc.legacy: Preparing import... [id=vpc-0abc123def456]
aws_vpc.legacy: Refreshing state...
...
Plan: 7 to import, 0 to add, 0 to change, 0 to destroy.
```

### Step 10: Examine Generated Configuration

```bash
cat generated.tf
```

The generated file contains all 7 resources with their current configuration. Notice:
- `tags_all` blocks (computed, must be removed)
- `null` values (can be removed)
- Hardcoded IDs (could be replaced with references)
- Computed attributes like `arn`, `id`, `owner_id` (must be removed)

---

## Part D: Clean Up Configuration (10 min)

### Step 11: Remove Computed Attributes

Edit `generated.tf` and remove:

1. **All `tags_all` blocks** - these are computed from `tags` + provider default_tags
2. **Lines with `= null`** - these are optional attributes not set
3. **Computed attributes:**
   - `arn` (on any resource)
   - `id` (on any resource)
   - `owner_id` (on VPC, security group)
   - `default_*` attributes on VPC (default_route_table_id, etc.)
   - `main_route_table_id` on VPC
   - `ipv6_*` attributes
   - `association_id` on route table association

### Step 12: Replace Hardcoded VPC ID

In the security group and subnet, replace the hardcoded VPC ID with a reference:

```hcl
# Before
vpc_id = "vpc-0abc123def456"

# After
vpc_id = aws_vpc.legacy.id
```

### Step 13: Add Data Source for AMI

The EC2 instance has a hardcoded AMI ID. Add a data source to look it up dynamically.

Create or edit `data.tf`:
```hcl
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}
```

Then in `generated.tf`, replace the hardcoded AMI:
```hcl
# Before
ami = "ami-0abc123def456"

# After
ami = data.aws_ami.amazon_linux_2023.id
```

> **Note:** Changing the AMI reference won't replace the instance since the actual AMI ID matches.

---

## Part E: Validate and Apply (5 min)

### Step 14: Validate Clean Plan

```bash
terraform plan
```

You should see:
```
Plan: 7 to import, 0 to add, 0 to change, 0 to destroy.
```

If you see changes, review the generated.tf for remaining computed attributes.

### Step 15: Apply Import

```bash
terraform apply
```

Type `yes` when prompted. Terraform will import all 7 resources into state.

### Step 16: Verify Clean State

```bash
terraform plan
```

You should now see:
```
No changes. Your infrastructure matches the configuration.
```

### Step 17: List Managed Resources

```bash
terraform state list
```

Expected output:
```
aws_instance.legacy
aws_internet_gateway.legacy
aws_route_table.public
aws_route_table_association.public
aws_security_group.legacy
aws_subnet.public
aws_vpc.legacy
```

---

## Part F: Protect Resources (5 min)

### Step 18: Add Lifecycle Protection

Edit `generated.tf` and add lifecycle blocks to critical resources:

```hcl
resource "aws_vpc" "legacy" {
  # ... existing config ...

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_instance" "legacy" {
  # ... existing config ...

  lifecycle {
    prevent_destroy = true
  }
}
```

### Step 19: Apply Protection

```bash
terraform apply
```

### Step 20: Verify Application Still Running

```bash
curl -s "http://${PUBLIC_IP}" | head -5
```

The application should still be serving traffic.

---

## Lab Complete!

You have successfully:
- Discovered existing AWS resources
- Written import blocks for 7 resources
- Generated Terraform configuration automatically
- Cleaned up computed attributes
- Achieved a clean `terraform plan`
- Protected critical resources with lifecycle blocks

### What's Next?

This imported single-server application could be evolved to a production-ready architecture:

1. **Add a second subnet** in another AZ for redundancy
2. **Add an Application Load Balancer** for traffic distribution
3. **Convert to Auto Scaling Group** for elasticity
4. **Add private subnets with NAT Gateway** for security

All of these additions can be made without recreating the original imported resources!

---

## Troubleshooting

### "Resource already exists" Error

If you see this error, the resource may already be in state from a previous attempt:

```bash
terraform state list
terraform state rm <resource_address>  # Remove if needed
terraform import <resource_address> <id>  # Or re-import
```

### Plan Shows Changes After Import

Common causes:
1. **tags_all not removed** - Delete all `tags_all` blocks
2. **Computed attributes remaining** - Remove `arn`, `id`, `owner_id`, etc.
3. **Null values** - Remove lines with `= null`

### EC2 Instance Replacement Warning

If Terraform wants to replace the instance, check:
- Is `user_data` specified? (Cannot be imported, may need to omit or match exactly)
- Is `ami` hardcoded vs using data source? (Should match actual AMI)

---

## Lab Completion Checklist

- [ ] Retrieved resource IDs from lab2-legacy-setup terraform output
- [ ] Updated terraform.tfvars with all 6 resource IDs
- [ ] Updated providers.tf backend with S3 bucket name
- [ ] Ran `terraform init` successfully
- [ ] Generated configuration with `terraform plan -generate-config-out`
- [ ] Removed `tags_all` blocks from generated.tf
- [ ] Removed null values and computed attributes
- [ ] Replaced hardcoded VPC ID with `aws_vpc.legacy.id`
- [ ] Added data source for AMI lookup
- [ ] Achieved clean `terraform plan` (0 changes)
- [ ] Applied import successfully (7 resources)
- [ ] Added `lifecycle { prevent_destroy = true }` to VPC and instance
- [ ] Verified application still running after import

---

## Appendix A: AWS CLI Discovery Commands

In a real-world scenario where infrastructure was created via the AWS Console, you would discover resources using the AWS CLI:

**VPC:**
```bash
aws ec2 describe-vpcs --filters "Name=tag:Student,Values=studentXX" \
  --query 'Vpcs[].VpcId' --output text
```

**Subnet:**
```bash
aws ec2 describe-subnets --filters "Name=tag:Student,Values=studentXX" \
  --query 'Subnets[].[Tags[?Key==`Name`].Value|[0],SubnetId]' --output table
```

**Internet Gateway:**
```bash
aws ec2 describe-internet-gateways --filters "Name=tag:Student,Values=studentXX" \
  --query 'InternetGateways[].InternetGatewayId' --output text
```

**Route Table:**
```bash
aws ec2 describe-route-tables --filters "Name=tag:Student,Values=studentXX" \
  --query 'RouteTables[].[Tags[?Key==`Name`].Value|[0],RouteTableId]' --output table
```

**Security Group:**
```bash
aws ec2 describe-security-groups --filters "Name=tag:Student,Values=studentXX" \
  --query 'SecurityGroups[].[GroupName,GroupId]' --output table
```

**EC2 Instance:**
```bash
aws ec2 describe-instances --filters "Name=tag:Student,Values=studentXX" \
  --query 'Reservations[].Instances[].[Tags[?Key==`Name`].Value|[0],InstanceId]' --output table
```
