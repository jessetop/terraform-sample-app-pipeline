# terraform.tfvars
# Replace studentXX with your assigned student ID
# Replace SUFFIX with the random suffix from your Lab 1 terraform output

student_id = "studentXX"

# This value comes from Lab 1 output. After running `terraform apply` in
# lab1-state-infra, run `terraform output` to get your actual value.
# Then update BOTH this file AND the backend block in providers.tf.

state_bucket_name = "studentXX-terraform-state-SUFFIX"

# =============================================================================
# RESOURCE IDs FOR IMPORT
# Discover these using AWS CLI commands, then paste the values below.
# =============================================================================

# Network Layer
# aws ec2 describe-vpcs --filters "Name=tag:Name,Values=*legacy-vpc*" --query 'Vpcs[].VpcId' --output text
vpc_id = "vpc-REPLACE_ME"

# aws ec2 describe-subnets --filters "Name=tag:Name,Values=*legacy*" --query 'Subnets[].[Tags[?Key==`Name`].Value|[0],SubnetId]' --output table
subnet_public_a_id  = "subnet-REPLACE_ME"
subnet_public_b_id  = "subnet-REPLACE_ME"
subnet_private_a_id = "subnet-REPLACE_ME"
subnet_private_b_id = "subnet-REPLACE_ME"

# aws ec2 describe-internet-gateways --filters "Name=tag:Name,Values=*legacy*" --query 'InternetGateways[].InternetGatewayId' --output text
internet_gateway_id = "igw-REPLACE_ME"

# aws ec2 describe-addresses --filters "Name=tag:Name,Values=*legacy*" --query 'Addresses[].AllocationId' --output text
eip_allocation_id = "eipalloc-REPLACE_ME"

# aws ec2 describe-nat-gateways --filter "Name=tag:Name,Values=*legacy*" --query 'NatGateways[].NatGatewayId' --output text
nat_gateway_id = "nat-REPLACE_ME"

# aws ec2 describe-route-tables --filters "Name=tag:Name,Values=*legacy*" --query 'RouteTables[].[Tags[?Key==`Name`].Value|[0],RouteTableId]' --output table
route_table_public_id  = "rtb-REPLACE_ME"
route_table_private_id = "rtb-REPLACE_ME"

# Security Layer
# aws ec2 describe-security-groups --filters "Name=tag:Name,Values=*legacy*" --query 'SecurityGroups[].[GroupName,GroupId]' --output table
security_group_alb_id = "sg-REPLACE_ME"
security_group_ec2_id = "sg-REPLACE_ME"

# Application Layer
# aws elbv2 describe-load-balancers --query 'LoadBalancers[?contains(LoadBalancerName,`legacy`)].LoadBalancerArn' --output text
alb_arn = "arn:aws:elasticloadbalancing:REGION:ACCOUNT:loadbalancer/app/NAME/ID"

# aws elbv2 describe-target-groups --query 'TargetGroups[?contains(TargetGroupName,`legacy`)].TargetGroupArn' --output text
target_group_arn = "arn:aws:elasticloadbalancing:REGION:ACCOUNT:targetgroup/NAME/ID"

# aws elbv2 describe-listeners --load-balancer-arn <ALB_ARN> --query 'Listeners[].ListenerArn' --output text
listener_arn = "arn:aws:elasticloadbalancing:REGION:ACCOUNT:listener/app/NAME/ID/ID"

# Compute Layer
# aws ec2 describe-launch-templates --filters "Name=tag:Name,Values=*legacy*" --query 'LaunchTemplates[].LaunchTemplateId' --output text
launch_template_id = "lt-REPLACE_ME"

# aws autoscaling describe-auto-scaling-groups --query 'AutoScalingGroups[?contains(AutoScalingGroupName,`legacy`)].AutoScalingGroupName' --output text
autoscaling_group_name = "studentXX-legacy-asg"
