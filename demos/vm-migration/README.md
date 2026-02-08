# VM Migration Demo: ESXi to AWS (Pipeline-Stage Architecture)

This demo migrates a Linux VM from VMware ESXi 8 to AWS EC2 using the **VM Import/Export** path. Each stage is an independent Terraform root module with its own state, designed to model a real CI/CD pipeline.

## Architecture

```
Stage 1          Stage 2          Stage 3          Stage 4          Stage 5          Stage 6
┌──────────┐     ┌──────────┐     ┌──────────┐     ┌──────────┐     ┌──────────┐     ┌──────────┐
│  AWS      │     │  vSphere │     │  OVF     │     │  S3      │     │  VM      │     │  EC2     │
│  Infra    │────>│  Source  │────>│  Export  │────>│  Upload  │────>│  Import  │────>│  Launch  │
│  Setup    │     │  Discover│     │          │     │          │     │          │     │          │
└──────────┘     └──────────┘     └──────────┘     └──────────┘     └──────────┘     └──────────┘
 Native TF        Native TF       local-exec       Native TF        local-exec       Native TF
 S3+IAM+VPC+SG    vSphere data    ovftool          aws_s3_object    ec2 import-image  aws_instance
```

**4 of 6 stages are pure HCL.** The 2 that use `local-exec` are justified — no Terraform resource exists for `ovftool` or `aws ec2 import-image`.

## Remote State Wiring

Stages communicate via `terraform_remote_state` — no manual copy-paste of outputs:

```
Stage 03 reads → Stage 02 (vm_name, esxi_host)
Stage 04 reads → Stage 01 (bucket_name) + Stage 03 (ova_path)
Stage 05 reads → Stage 01 (region) + Stage 04 (s3_bucket, s3_key)
Stage 06 reads → Stage 01 (subnet, sg) + Stage 05 (ami_id)
```

## Prerequisites

- AWS account with appropriate permissions
- AWS CLI configured with credentials
- Terraform >= 1.5.0
- VMware ESXi 8.x host with a Linux VM to migrate
- `ovftool` installed (for Stage 03)
- An S3 bucket for Terraform state (see `_backend.tf.example`)

## Project Structure

```
vm-migration/
├── README.md
├── _backend.tf.example              # Template for S3 backend configuration
├── stages/
│   ├── 01-aws-infra/                # S3 bucket, IAM vmimport role, VPC, SGs
│   ├── 02-vsphere-discovery/        # vSphere data sources: datacenter, datastore, VM
│   ├── 03-ovf-export/               # null_resource + local-exec (ovftool)
│   ├── 04-s3-upload/                # aws_s3_object (native TF — replaces bash script)
│   ├── 05-vm-import/                # null_resource + local-exec (aws ec2 import-image)
│   └── 06-ec2-launch/               # aws_instance + aws_eip (native TF)
└── legacy/                          # Old modules kept as reference
    ├── 01-aws-mgn-setup/
    ├── 02-esxi-source/
    └── 03-fallback-vmimport/
```

## Quick Start

### 1. Configure Backend

Create an S3 bucket for Terraform state, then replace `YOUR-STATE-BUCKET-NAME` in each stage's `providers.tf` with your bucket name. See `_backend.tf.example` for details.

### 2. Run Stages in Sequence

```bash
# Stage 01: Create AWS infrastructure (S3, IAM, VPC, SGs)
cd stages/01-aws-infra
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars
terraform init && terraform apply

# Stage 02: Discover source VM on ESXi
cd ../02-vsphere-discovery
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with ESXi credentials
terraform init && terraform apply

# Stage 03: Export VM from ESXi (requires ovftool)
cd ../03-ovf-export
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars
terraform init && terraform apply

# Stage 04: Upload OVA to S3 (native Terraform — no scripts)
cd ../04-s3-upload
cp terraform.tfvars.example terraform.tfvars
terraform init && terraform apply

# Stage 05: Import OVA as AMI (takes 20-60+ minutes)
cd ../05-vm-import
cp terraform.tfvars.example terraform.tfvars
terraform init && terraform apply

# Stage 06: Launch EC2 instance from imported AMI
cd ../06-ec2-launch
cp terraform.tfvars.example terraform.tfvars
terraform init && terraform apply
```

## Pipeline Mapping (with VPN)

Each stage maps directly to a CI/CD pipeline stage:

| Pipeline Stage | Terraform Stage | Runner | Approval Gate? |
|---|---|---|---|
| Provision | 01-aws-infra | CodeBuild | No |
| Discover | 02-vsphere-discovery | Self-hosted (VPN) | No |
| Export | 03-ovf-export | Self-hosted (ESXi) | Yes |
| Upload | 04-s3-upload | Self-hosted | No |
| Import | 05-vm-import | CodeBuild (long timeout) | Yes |
| Launch | 06-ec2-launch | CodeBuild | Yes |

## Stage Details

| Stage | Creates | Key Resource | Pure HCL? |
|---|---|---|---|
| 01-aws-infra | S3 bucket, IAM vmimport role, VPC, subnet, SGs | `aws_s3_bucket`, `aws_iam_role` | Yes |
| 02-vsphere-discovery | Nothing (data sources only) | `data.vsphere_virtual_machine` | Yes |
| 03-ovf-export | Exports VM to local OVA file | `null_resource` (ovftool) | No |
| 04-s3-upload | Uploads OVA to S3 | `aws_s3_object` | Yes |
| 05-vm-import | Converts OVA to AMI | `null_resource` (import-image) | No |
| 06-ec2-launch | Running EC2 instance | `aws_instance`, `aws_eip` | Yes |

## Comparing Old vs New

The `legacy/` directory contains the old monolithic approach for comparison:

| Aspect | Old (legacy/) | New (stages/) |
|---|---|---|
| State isolation | None — one big state | Each stage has its own state |
| Bash scripts | 3 generated scripts | 0 scripts — HCL or justified local-exec |
| S3 upload | 96-line bash script | Single `aws_s3_object` resource |
| Stage communication | Manual copy-paste of outputs | `terraform_remote_state` data sources |
| CI/CD ready | No | Yes — each stage is a pipeline stage |

## Troubleshooting

### VM Import Fails
1. Check vmimport service role exists and is trusted
2. Verify S3 bucket policy allows vmimport service
3. Check disk format is supported (VMDK, OVA, VHD, RAW)
4. Review: `aws ec2 describe-import-image-tasks --import-task-ids <task-id>`

### ovftool Export Fails
1. Verify VM is powered off for clean export
2. Check network connectivity to ESXi host
3. Ensure `ovftool` is in PATH

## Cleanup

```bash
# Destroy in reverse order
cd stages/06-ec2-launch   && terraform destroy
cd ../05-vm-import        && terraform destroy
cd ../04-s3-upload        && terraform destroy
cd ../03-ovf-export       && terraform destroy
cd ../02-vsphere-discovery && terraform destroy
cd ../01-aws-infra        && terraform destroy
```
