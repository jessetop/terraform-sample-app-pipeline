# VM Migration Demo: ESXi to AWS

This demo shows how to migrate a Linux VM from VMware ESXi 8 to AWS using two approaches:

1. **Primary: AWS Application Migration Service (MGN)** - Industry standard, near-zero downtime
2. **Fallback: VM Import/Export** - When MGN agent can't be installed or network is restricted

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           PRIMARY PATH: MGN                                  │
│                                                                              │
│  ┌──────────────┐         HTTPS/1500          ┌────────────────────────┐    │
│  │   ESXi 8     │         (Public Internet)    │        AWS             │    │
│  │  ┌────────┐  │ ───────────────────────────► │  ┌──────────────────┐ │    │
│  │  │Linux VM│  │   Block-level replication    │  │ Replication Srvr │ │    │
│  │  │+ Agent │  │                              │  │   (Staging Area) │ │    │
│  │  └────────┘  │                              │  └────────┬─────────┘ │    │
│  └──────────────┘                              │           │           │    │
│                                                │           ▼           │    │
│                                                │  ┌──────────────────┐ │    │
│                                                │  │  Launch Instance │ │    │
│                                                │  │   (Test/Cutover) │ │    │
│                                                │  └──────────────────┘ │    │
│                                                └────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                        FALLBACK PATH: VM Import                              │
│                                                                              │
│  ┌──────────────┐                              ┌────────────────────────┐    │
│  │   ESXi 8     │      ovftool export          │        AWS             │    │
│  │  ┌────────┐  │ ──────────┐                  │                        │    │
│  │  │Linux VM│  │           │                  │  ┌──────────────────┐ │    │
│  │  └────────┘  │           ▼                  │  │    S3 Bucket     │ │    │
│  └──────────────┘      ┌─────────┐   AWS CLI   │  │   (OVA/VMDK)     │ │    │
│                        │OVA/VMDK│ ───────────► │  └────────┬─────────┘ │    │
│                        └─────────┘   Upload    │           │           │    │
│                                                │           ▼ vm-import │    │
│                                                │  ┌──────────────────┐ │    │
│                                                │  │       AMI        │ │    │
│                                                │  └────────┬─────────┘ │    │
│                                                │           ▼           │    │
│                                                │  ┌──────────────────┐ │    │
│                                                │  │   EC2 Instance   │ │    │
│                                                │  └──────────────────┘ │    │
│                                                └────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Prerequisites

### AWS Side
- AWS account with appropriate permissions
- AWS CLI configured with credentials
- Terraform >= 1.5.0

### ESXi Side
- VMware ESXi 8.x host
- SSH access to ESXi
- `ovftool` installed (for fallback path)
- A Linux VM to migrate (Ubuntu/RHEL/Amazon Linux recommended)

### Network Requirements (MGN)
- Source VM needs outbound internet access:
  - Port 443 (HTTPS) to AWS MGN endpoints
  - Port 1500 (TCP) to replication servers

## Project Structure

```
vm-migration/
├── README.md                     # This file
├── 01-aws-mgn-setup/             # AWS MGN infrastructure
│   ├── providers.tf
│   ├── variables.tf
│   ├── main.tf                   # MGN config, IAM, networking
│   ├── outputs.tf
│   └── terraform.tfvars.example
│
├── 02-esxi-source/               # ESXi connection and agent setup
│   ├── providers.tf
│   ├── variables.tf
│   ├── main.tf                   # vSphere data sources
│   ├── outputs.tf
│   ├── terraform.tfvars.example
│   └── scripts/
│       ├── install-mgn-agent.sh  # Agent installer for Linux
│       └── verify-agent.sh       # Verify agent status
│
└── 03-fallback-vmimport/         # Fallback: OVA export → S3 → AMI
    ├── providers.tf
    ├── variables.tf
    ├── main.tf                   # S3 bucket, IAM vmimport role
    ├── outputs.tf
    ├── terraform.tfvars.example
    └── scripts/
        ├── export-vm.sh          # Export VM from ESXi
        ├── upload-to-s3.sh       # Upload OVA to S3
        └── import-image.sh       # Trigger vm-import
```

## Quick Start

### Path A: MGN (Recommended)

```bash
# Step 1: Set up AWS MGN infrastructure
cd 01-aws-mgn-setup
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
terraform init && terraform apply

# Step 2: Note the outputs (agent download URL, etc.)
terraform output

# Step 3: Install agent on source VM
cd ../02-esxi-source
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with ESXi credentials
terraform init && terraform apply

# Step 4: SSH to your Linux VM and run the agent installer
# (Use the script from scripts/install-mgn-agent.sh)

# Step 5: Monitor replication in AWS Console → MGN → Source servers
# Step 6: Launch test instance, verify, then cutover
```

### Path B: VM Import (Fallback)

```bash
# Step 1: Set up AWS import infrastructure
cd 03-fallback-vmimport
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars
terraform init && terraform apply

# Step 2: Export VM from ESXi
./scripts/export-vm.sh

# Step 3: Upload to S3
./scripts/upload-to-s3.sh

# Step 4: Trigger import
./scripts/import-image.sh

# Step 5: Monitor import progress
aws ec2 describe-import-image-tasks

# Step 6: Launch instance from resulting AMI
```

## Choosing Between MGN and VM Import

| Criteria | MGN | VM Import |
|----------|-----|-----------|
| Downtime | Near-zero (continuous replication) | Hours (export + upload + import) |
| Network requirement | Outbound internet from VM | Only need to upload files |
| Complexity | Moderate (agent install) | Simple (file transfer) |
| Large VMs | Better (incremental sync) | Slower (full export each time) |
| Airgapped source | Not possible | Works fine |

## Troubleshooting

### MGN Agent Won't Connect
1. Check outbound connectivity: `curl -v https://mgn.us-east-1.amazonaws.com`
2. Check port 1500: `nc -zv <replication-server-ip> 1500`
3. Verify IAM credentials on the agent
4. Check security group allows outbound 443 and 1500

### VM Import Fails
1. Check vmimport service role exists and is trusted
2. Verify S3 bucket policy allows vmimport service
3. Check disk format is supported (VMDK, OVA, VHD, RAW)
4. Review import task errors: `aws ec2 describe-import-image-tasks --import-task-ids <task-id>`

## Cost Considerations

- **MGN**: Free for 90 days per source server, then $0.042/hr per replicating server
- **S3**: Storage costs for OVA files (~$0.023/GB/month)
- **Data transfer**: Outbound from ESXi to AWS (your internet costs)
- **EBS snapshots**: Created during import (~$0.05/GB/month)

## Cleanup

```bash
# Remove AWS MGN resources
cd 01-aws-mgn-setup && terraform destroy

# Remove fallback resources
cd ../03-fallback-vmimport && terraform destroy

# Don't forget to:
# - Delete any launched test instances
# - Remove source servers from MGN console
# - Delete imported AMIs and their snapshots
# - Empty and delete S3 buckets
```
