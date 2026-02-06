# Lab 2 Legacy Setup

This creates the "legacy" infrastructure that you will import in Lab 2.

## Narrative

This simulates infrastructure created 2 years ago by an engineer who has since left the company. The application was built through the AWS Console with no infrastructure-as-code.

**After running this setup, close this folder and pretend it doesn't exist.** Your job in Lab 2 is to discover and import these resources using only the AWS CLI and Terraform import blocks.

## What Gets Created

| Resource Type | Count | Name Pattern |
|---------------|-------|--------------|
| VPC | 1 | `studentXX-legacy-vpc` |
| Subnets | 4 | `studentXX-legacy-{public,private}-{a,b}` |
| Internet Gateway | 1 | `studentXX-legacy-igw` |
| Route Tables | 2 | `studentXX-legacy-{public,private}-rt` |
| Route Table Associations | 4 | (no name) |
| Security Groups | 2 | `studentXX-legacy-{alb,ec2}-sg` |
| Application Load Balancer | 1 | `studentXX-legacy-alb` |
| Target Group | 1 | `studentXX-legacy-tg` |
| ALB Listener | 1 | (HTTP:80) |
| Launch Template | 1 | `studentXX-legacy-lt` |
| Auto Scaling Group | 1 | `studentXX-legacy-asg` |

**Total: ~21 resources** (depending on how you count associations)

## Usage

```bash
cd lab2-legacy-setup

# Update terraform.tfvars with your student ID
# student_id = "student01"

terraform init
terraform apply
```

After apply completes, note the ALB DNS name and test the app:
```bash
curl http://$(terraform output -raw alb_dns_name)
```

## Cost

- **ALB**: ~$0.02/hour (~$0.50/day)
- **EC2 (2x t3.micro)**: Free tier eligible, otherwise ~$0.02/hour
- **No NAT Gateway**: Saves ~$0.045/hour

**Estimated cost: ~$1-2/day** (destroy when done!)

## Cleanup

After completing Lab 2:
```bash
cd lab2-legacy-setup
terraform destroy
```
