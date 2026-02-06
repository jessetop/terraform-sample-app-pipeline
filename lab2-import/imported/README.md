# Imported Resources Reference

These files show what the generated Terraform config should look like after a successful import.

**DO NOT copy these files to the parent directory** - the lab exercise is to generate them yourself using:

```bash
terraform plan -generate-config-out=generated.tf
```

## Files

- `data.tf` - AMI data source lookup
- `network.tf` - VPC, subnets, IGW, NAT gateway, route tables
- `security.tf` - Security groups for ALB and EC2
- `alb.tf` - Application Load Balancer, target group, listener
- `compute.tf` - Launch template and Auto Scaling Group

## Key Points

1. All resources use `var.student_id` instead of hardcoded values
2. AMI uses a data source lookup, not a hardcoded ID
3. The import blocks in `imports.tf` tell Terraform which existing resources to import
4. After import, these resources are managed by Terraform in the new state file
