# Imported Resources Reference

These files show what the generated Terraform config should look like after a successful import.

**DO NOT copy these files to the parent directory** - the lab exercise is to generate them yourself using:

```bash
terraform plan -generate-config-out=generated.tf
```

## Files

- `data.tf` - Availability zones and AMI data source lookup
- `network.tf` - VPC, subnet, internet gateway, route table
- `security.tf` - Security group for the web server
- `compute.tf` - EC2 instance

## Resources (7 total)

1. VPC
2. Public Subnet
3. Internet Gateway
4. Route Table
5. Route Table Association
6. Security Group
7. EC2 Instance

## Key Points

1. All resources use `var.student_id` instead of hardcoded values
2. AMI uses a data source lookup, not a hardcoded ID
3. The import blocks in `imports.tf` tell Terraform which existing resources to import
4. After import, these resources are managed by Terraform in the new state file

## Next Steps After Import

After successfully importing this single-server legacy app, you could evolve it to a production-ready architecture by adding:

- Multiple availability zones
- Load balancing (ALB)
- Auto scaling
- Private subnets with NAT gateway

All without recreating the original imported resources!
