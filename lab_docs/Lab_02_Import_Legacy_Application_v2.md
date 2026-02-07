# Lab 2: Import Legacy Application

*Terraform Day 3: Enterprise Deployment & Operations*

| | |
|---|---|
| **Course** | Terraform on AWS (300-Level) |
| **Module** | Terraform Import |
| **Duration** | 75 minutes |
| **Difficulty** | Advanced |
| **Prerequisites** | Lab 1 completed, Legacy app deployed by instructor |
| **Terraform** | >= 1.5.0 (import blocks + config generation) |

---

## Lab Overview

### Narrative

NovaTech's "Customer Portal" application was deployed two years ago by an engineer who has since left the company. The application was built entirely through the AWS Console -- click by click -- with no infrastructure-as-code, no version history, and no reproducible deployment process. It runs as a classic three-tier web application: an Application Load Balancer forwards traffic to an Auto Scaling Group of EC2 instances running Apache httpd, all sitting inside a custom VPC with public and private subnets, a NAT Gateway, and carefully configured security groups.

The application serves 10,000 daily active users and generates revenue around the clock. It cannot be interrupted.

Last week, SOC 2 auditors flagged the Customer Portal as "unmanaged infrastructure" -- a compliance finding that must be remediated before the next audit cycle. Jordan, your team lead, assigns you the task: bring the entire application stack under Terraform management without any downtime. No rebuilding, no replacing -- you must adopt the existing resources exactly as they are.

### What's Different in This Version

This lab uses a **single-pass import workflow** -- the approach experienced practitioners use for large-scale imports:

1. **Discover everything first** -- complete inventory before touching Terraform
2. **Write all import blocks at once** -- one file declaring every resource to import
3. **Generate all configuration in a single run** -- one `terraform plan -generate-config-out` produces HCL for all 21 resources
4. **Clean up systematically** -- split generated code into organized files, remove computed attributes, replace hardcoded IDs with references
5. **Apply once** -- a single `terraform apply` imports all resources into state

This mirrors how you would import a production application stack at your own organization.

### Learning Objectives

By the end of this lab, you will:

- Systematically discover and inventory existing AWS resources using the AWS CLI
- Write all import blocks for a complete application stack in a single declaration file
- Use `terraform plan -generate-config-out` to auto-generate HCL configuration for all resources in one pass
- Refactor generated configuration by removing computed attributes, replacing hardcoded IDs with resource references, and organizing code into logical files
- Achieve a completely clean `terraform plan` showing zero changes across all 21 resources

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                          VPC: 10.0.0.0/16                                           │
│                          studentXX-legacy-vpc                                       │
│                                                                                     │
│   ┌───────────────────────────────────┐   ┌───────────────────────────────────┐    │
│   │     Public Subnet A (AZ-a)        │   │     Public Subnet B (AZ-b)        │    │
│   │        10.0.1.0/24                │   │        10.0.2.0/24                │    │
│   │                                   │   │                                   │    │
│   │  ┌─────────────┐  ┌───────────┐  │   │  ┌─────────────┐                  │    │
│   │  │ NAT Gateway │  │    ALB    │◄─┼───┼──┤    ALB      │                  │    │
│   │  │ + Elastic IP│  │  (node)   │  │   │  │   (node)    │                  │    │
│   │  └──────┬──────┘  └─────┬─────┘  │   │  └─────┬───────┘                  │    │
│   │         │               │         │   │        │                          │    │
│   └─────────┼───────────────┼─────────┘   └────────┼──────────────────────────┘    │
│             │               │                      │                               │
│             │         ┌─────┴──────────────────────┘                               │
│             │         │  ALB Security Group (port 80 from 0.0.0.0/0)               │
│             │         │                                                             │
│   ┌─────────┼─────────┼──────────────────┐   ┌───────────────────────────────────┐ │
│   │  Private│Subnet A │(AZ-a)            │   │     Private Subnet B (AZ-b)       │ │
│   │      10.0.10.0/24 │                  │   │        10.0.20.0/24               │ │
│   │         │         ▼                  │   │                                   │ │
│   │         │  ┌──────────────┐          │   │  ┌──────────────┐                 │ │
│   │         │  │  EC2 (httpd) │          │   │  │  EC2 (httpd) │                 │ │
│   │         │  │  t3.micro    │          │   │  │  t3.micro    │                 │ │
│   │         │  └──────────────┘          │   │  └──────────────┘                 │ │
│   │         │   ASG: min=1, max=4,       │   │   EC2 SG (port 80 from ALB SG)   │ │
│   │         │        desired=2           │   │                                   │ │
│   └─────────┼────────────────────────────┘   └───────────────────────────────────┘ │
│             │                                                                       │
│   ┌─────────┴──────────┐      ┌──────────────────┐                                 │
│   │  Private Route Tbl  │      │  Public Route Tbl │                                │
│   │  0.0.0.0/0 → NAT   │      │  0.0.0.0/0 → IGW │                                │
│   └────────────────────┘      └──────────────────┘                                 │
│                                                                                     │
│   ┌─────────────────┐                                                              │
│   │ Internet Gateway │◄──── Internet                                               │
│   │ studentXX-legacy │                                                              │
│   └─────────────────┘                                                              │
│                                                                                     │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### Key Concepts

| Term | Definition |
|------|------------|
| **Import Block** | Declarative HCL block (Terraform 1.5+) that maps a Terraform resource address to a real-world resource ID. Replaces the older `terraform import` CLI command. |
| **Config Generation** | `terraform plan -generate-config-out` reads import blocks, queries AWS for live state, and writes HCL resource blocks that describe what exists. |
| **Single-Pass Import** | Writing all import blocks first, generating all config at once, then applying -- rather than importing layer by layer. |
| **Computed Attribute** | A resource attribute calculated by AWS at creation time (e.g., ARN, ID, `tags_all`) that must not appear in HCL configuration. |
| **Clean Plan** | A `terraform plan` output showing zero additions, changes, or destructions -- proving config matches reality. |

---

## Pre-Deployed Legacy Resources

Your instructor has deployed the following resources tagged with your student ID:

| Resource Type | Name Pattern | ID Format |
|---------------|--------------|-----------|
| VPC | `studentXX-legacy-vpc` | `vpc-xxxxxxxxx` |
| Public Subnet A | `studentXX-legacy-public-a` | `subnet-xxxxxxxxx` |
| Public Subnet B | `studentXX-legacy-public-b` | `subnet-xxxxxxxxx` |
| Private Subnet A | `studentXX-legacy-private-a` | `subnet-xxxxxxxxx` |
| Private Subnet B | `studentXX-legacy-private-b` | `subnet-xxxxxxxxx` |
| Internet Gateway | `studentXX-legacy-igw` | `igw-xxxxxxxxx` |
| NAT Gateway | `studentXX-legacy-nat` | `nat-xxxxxxxxx` |
| Elastic IP | `studentXX-legacy-nat-eip` | `eipalloc-xxxxxxxxx` |
| Public Route Table | `studentXX-legacy-public-rt` | `rtb-xxxxxxxxx` |
| Private Route Table | `studentXX-legacy-private-rt` | `rtb-xxxxxxxxx` |
| ALB Security Group | `studentXX-legacy-alb-sg` | `sg-xxxxxxxxx` |
| EC2 Security Group | `studentXX-legacy-ec2-sg` | `sg-xxxxxxxxx` |
| Application Load Balancer | `studentXX-legacy-alb` | ARN |
| Target Group | `studentXX-legacy-tg` | ARN |
| ALB Listener (HTTP:80) | -- | ARN |
| Launch Template | `studentXX-legacy-lt` | `lt-xxxxxxxxx` |
| Auto Scaling Group | `studentXX-legacy-asg` | Name (string) |

Replace `studentXX` with your assigned student ID throughout this lab.

---

## Part A: Resource Discovery & Configuration (15 min)

Before writing a single line of Terraform, you need to know exactly what exists. In a real engagement, documentation may be missing or wrong. The AWS CLI is your source of truth.

### Step 1: Navigate to the Lab Directory

```bash
cd lab2-import
```

### Step 2: Review the Lab Files

The lab directory includes pre-created configuration files:

| File | Purpose |
|------|---------|
| `providers.tf` | AWS provider with S3 backend (needs bucket name from Lab 1) |
| `variables.tf` | Variables for all resource IDs to import |
| `terraform.tfvars` | Where you'll paste discovered resource IDs |
| `imports.tf` | Import blocks using variables (no hardcoded IDs) |

> **Note:** The import blocks in `imports.tf` use variables instead of hardcoded IDs. This means you only need to update `terraform.tfvars` with your discovered resource IDs.

### Step 3: Get Resource IDs

**Real-World Approach:** In a real engagement with legacy console-created infrastructure, you would discover each resource by tag using AWS CLI commands. These could be scripted, but you'd run queries like:

```bash
# Example: Discover VPC by tag
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=*legacy-vpc*" \
  --query 'Vpcs[].VpcId' --output text

# Example: Discover subnets by tag
aws ec2 describe-subnets --filters "Name=tag:Name,Values=*legacy*" \
  --query 'Subnets[].[Tags[?Key==`Name`].Value|[0],SubnetId]' --output table
```

The `terraform.tfvars` file includes all the AWS CLI discovery commands as comments for reference.

**Lab Shortcut:** Since we deployed the legacy infrastructure using Terraform in `lab2-legacy-setup`, all the resource IDs are available as outputs. Simply run:

```bash
cd ../lab2-legacy-setup
terraform output
```

This displays all resource IDs in the same order as `terraform.tfvars`. Copy the values into `lab2-import/terraform.tfvars`.

### Step 4: Update Configuration Files

1. Edit `lab2-import/terraform.tfvars` and paste the resource IDs from the terraform output.

2. Edit `lab2-import/providers.tf` and update the backend bucket name with your value from Lab 1.

> **Important:** For subnets, public subnets have `MapPublicIpOnLaunch = true`, private subnets have `false`.

### Step 5: Verify the Application is Running

Before touching anything, confirm the application is live:

```bash
ALB_DNS=$(aws elbv2 describe-load-balancers \
  --query "LoadBalancers[?contains(LoadBalancerName,'legacy')].DNSName" \
  --output text)

echo "Application URL: http://${ALB_DNS}"
curl -s "http://${ALB_DNS}" | head -5
```

Expected output:
```
<h1>Hello from Legacy App - ip-10-0-10-xxx</h1>
```

The application is live. It must remain live throughout this entire lab.

---

## Part B: Initialize and Generate Configuration (15 min)

### Step 6: Initialize Terraform

```bash
terraform init
```

Terraform connects to the S3 backend created in Lab 1. S3 native locking (`use_lockfile = true`) prevents concurrent operations.

### Step 7: Generate Configuration

Run config generation for all resources at once:

```bash
terraform plan -generate-config-out=generated.tf
```

Expected output:
```
aws_vpc.legacy: Preparing import... [id=vpc-xxxxxxxxx]
aws_vpc.legacy: Refreshing state... [id=vpc-xxxxxxxxx]
...
aws_autoscaling_group.legacy: Preparing import... [id=studentXX-legacy-asg]
aws_autoscaling_group.legacy: Refreshing state... [id=studentXX-legacy-asg]

Plan: 21 to import, 0 to add, 0 to change, 0 to destroy.
```

Terraform creates `generated.tf` containing auto-generated HCL for all 21 resources.

### Step 8: Examine Generated Configuration

Open `generated.tf` and review it. The generated code is functional but includes:

- **Computed attributes** (`arn`, `id`, `owner_id`, `tags_all`) that will cause errors
- **Null and default values** that clutter the code
- **Hardcoded IDs** where resource references should be used
- **Empty blocks** for features not in use

> **Do NOT apply the generated config directly.** It will cause perpetual plan drift because of `tags_all` and other computed attributes.

---

## Part C: Refactor Generated Config (25 min)

You will now clean up the generated configuration. For reference, the `imported/` directory contains example files showing what clean config should look like.

### Step 9: Review Reference Files

The `imported/` directory contains completed configuration files:

```bash
ls imported/
```

| File | Contents |
|------|----------|
| `data.tf` | AMI data source lookup |
| `network.tf` | VPC, subnets, IGW, NAT gateway, route tables |
| `security.tf` | Security groups for ALB and EC2 |
| `alb.tf` | Application Load Balancer, target group, listener |
| `compute.tf` | Launch template and Auto Scaling Group |

> **Important:** Do NOT copy these files directly -- the exercise is to create them yourself using the generated config as your starting point. Use the reference files to understand the target structure.

### Step 10: Create Clean Configuration Files

Using `generated.tf` as input and the `imported/` files as reference, create clean versions:

1. **Create `data.tf`** - Add an AMI data source instead of using hardcoded AMI IDs:

```hcl
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

2. **Create `network.tf`** - Extract VPC, subnets, gateways, and route tables. Key changes:
   - Remove `tags_all` blocks
   - Replace hardcoded VPC IDs with `aws_vpc.legacy.id`
   - Replace hardcoded subnet IDs with references
   - Use `var.student_id` in Name tags

3. **Create `security.tf`** - Extract security groups:
   - Remove `tags_all` blocks
   - Reference VPC with `aws_vpc.legacy.id`
   - Reference ALB security group in EC2 ingress rules

4. **Create `alb.tf`** - Extract ALB, target group, and listener:
   - Remove `tags_all` blocks
   - Reference security groups and subnets
   - Remove empty blocks like `access_logs {}`

5. **Create `compute.tf`** - Extract launch template and ASG:
   - Use `data.aws_ami.amazon_linux_2023.id` for the AMI
   - Reference security groups and subnets
   - Use `var.student_id` in names and tags

6. **Create `outputs.tf`** - Add useful outputs:

```hcl
output "alb_dns_name" {
  description = "DNS name of the legacy application load balancer"
  value       = aws_lb.legacy.dns_name
}

output "alb_url" {
  description = "Application URL"
  value       = "http://${aws_lb.legacy.dns_name}"
}
```

### What to Remove from Generated Config

| Pattern to Remove | Reason |
|-------------------|--------|
| `tags_all = { ... }` | Computed from `tags` + provider `default_tags` |
| Attributes set to `null` | Omitting has the same effect |
| Default-value attributes | Unnecessary noise |
| Hardcoded IDs | Replace with resource references |
| Empty blocks | Features not in use |
| Computed outputs (`arn`, `owner_id`) | Read-only |

### Step 11: Delete Generated File

After creating clean config files:

```bash
rm generated.tf
```

---

## Part D: Import All Resources (10 min)

### Step 12: Validate the Plan

```bash
terraform plan
```

You are looking for:
```
Plan: 21 to import, 0 to add, 0 to change, 0 to destroy.
```

If you see planned **changes** (not just imports), common causes include:

| Plan Shows | Fix |
|------------|-----|
| `~ tags` being modified | A tag doesn't match exactly |
| `~ user_data` (forces replacement!) | Base64 encoding mismatch |
| `+ tags_all` appearing | Remove `tags_all` from config |
| `~ egress` or `~ ingress` | Rule details don't match exactly |

Iterate: edit your `.tf` files, re-run `terraform plan`, repeat until the plan shows only imports.

### Step 13: Apply All Imports

Once the plan is clean:

```bash
terraform apply
```

Type `yes` when prompted.

Expected output:
```
aws_vpc.legacy: Importing... [id=vpc-xxxxxxxxx]
aws_vpc.legacy: Import complete [id=vpc-xxxxxxxxx]
...
aws_autoscaling_group.legacy: Importing... [id=studentXX-legacy-asg]
aws_autoscaling_group.legacy: Import complete [id=studentXX-legacy-asg]

Apply complete! Resources: 21 imported, 0 added, 0 changed, 0 destroyed.
```

### Step 14: Verify Clean State

Run an immediate follow-up plan:

```bash
terraform plan
```

Expected output:
```
No changes. Your infrastructure matches the configuration.
```

Verify all resources are in state:

```bash
terraform state list
```

You should see 21 resources.

### Step 15: Verify Application Health

Confirm zero downtime:

```bash
curl -s "http://$(terraform output -raw alb_dns_name)"
```

The application continued serving traffic throughout the entire import process.

---

## Part E: Archive Import Blocks (5 min)

The import blocks have served their purpose. They only execute once -- on subsequent plans and applies, Terraform uses the state file to track these resources.

### Step 16: Move Import Blocks

```bash
mkdir -p completed_imports
mv imports.tf completed_imports/
```

### Step 17: Final Verification

```bash
terraform plan
```

```
No changes. Your infrastructure matches the configuration.
```

---

## Troubleshooting

### Issue 1: "Resource not found" During Import

**Cause:** The resource ID in terraform.tfvars does not match any resource in AWS.

**Fix:**
- Verify the resource ID format (ALB uses ARN, ASG uses name)
- Re-run discovery commands and compare IDs
- Check the AWS region (`us-east-1`)

### Issue 2: Route Table Association Import Errors

**Note:** Route table associations use a composite ID format: `subnet-id/route-table-id`. The provided `imports.tf` constructs this automatically from your subnet and route table variables.

### Issue 3: Plan Shows Changes After Import

**Cause:** Your HCL configuration does not exactly match the actual resource state.

**Fix:**
- Read the plan output to see which attributes differ
- For tags: ensure every tag matches exactly
- For security group rules: ensure all fields match

### Issue 4: User Data Drift on Launch Template

**Cause:** The `base64encode()` function produces a different string than what AWS stored.

**Fix:** Retrieve the exact base64 from AWS and use it directly:
```bash
aws ec2 describe-launch-template-versions \
  --launch-template-id lt-xxxxxxxxx \
  --versions '$Latest' \
  --query 'LaunchTemplateVersions[0].LaunchTemplateData.UserData' \
  --output text
```

---

## Knowledge Check

**Question 1:** Why does the single-pass approach work better than importing layer by layer?

*Answer:* When all import blocks are declared together, Terraform sees the full picture. A single `terraform apply` imports all resources atomically. The layer-by-layer approach requires multiple cycles and risks partial state.

**Question 2:** What is the difference between the resource ID format for an ALB versus an Auto Scaling Group?

*Answer:* ALB uses its full ARN. ASG uses its name as a plain string. Each resource type documents its import ID format in the Terraform Registry.

**Question 3:** Why must `tags_all` be removed from generated configuration?

*Answer:* `tags_all` is computed by merging `tags` with provider `default_tags`. Including it causes a perpetual diff because Terraform sees a conflict between the computed value and your hardcoded value.

---

## Lab Completion Checklist

- [ ] Discovered all legacy resources using AWS CLI commands
- [ ] Updated `terraform.tfvars` with resource IDs
- [ ] Updated `providers.tf` with S3 bucket name from Lab 1
- [ ] Ran `terraform init` with remote backend
- [ ] Ran `terraform plan -generate-config-out=generated.tf`
- [ ] Created clean config files (network.tf, security.tf, alb.tf, compute.tf, data.tf, outputs.tf)
- [ ] Achieved `Plan: 21 to import, 0 to add, 0 to change, 0 to destroy`
- [ ] Ran `terraform apply` and imported all 21 resources
- [ ] Confirmed `terraform plan` shows `No changes` after import
- [ ] Verified `terraform state list` shows 21 managed resources
- [ ] Verified application still serves traffic
- [ ] Archived `imports.tf` after successful import

---

## Cost Considerations

**What This Lab Created:**

This lab creates **no new AWS resources**. You are importing management of resources that already exist.

| Item | Cost Impact |
|------|------------|
| Terraform state file in S3 | Negligible (a few KB) |
| Existing legacy resources | Already running -- no change |

**Important:** Do **not** run `terraform destroy` on this configuration. Destroying would delete the legacy application stack and cause an outage.

---

## Next Steps

In **Lab 3**, you will take the Terraform configuration you created in this lab and push it through an automated CI/CD pipeline.

---

## Additional Resources

- [Terraform Import Block Documentation](https://developer.hashicorp.com/terraform/language/import)
- [Generating Configuration with Import](https://developer.hashicorp.com/terraform/language/import/generating-configuration)
- [AWS Provider: Resource Import](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [terraform plan -generate-config-out](https://developer.hashicorp.com/terraform/cli/commands/plan#generate-config-out)
