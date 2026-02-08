# main.tf - AWS Application Migration Service (MGN) infrastructure
#
# This configuration sets up:
# 1. VPC and networking (optional - can use existing)
# 2. IAM roles for MGN service
# 3. MGN replication configuration template
# 4. Security groups for replication servers

locals {
  vpc_id    = var.use_existing_vpc ? var.existing_vpc_id : aws_vpc.mgn[0].id
  subnet_id = var.use_existing_vpc ? var.existing_subnet_id : aws_subnet.staging[0].id
}

# =============================================================================
# NETWORKING (Optional - only created if use_existing_vpc = false)
# =============================================================================

resource "aws_vpc" "mgn" {
  count = var.use_existing_vpc ? 0 : 1

  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-mgn-vpc"
  }
}

resource "aws_internet_gateway" "mgn" {
  count = var.use_existing_vpc ? 0 : 1

  vpc_id = aws_vpc.mgn[0].id

  tags = {
    Name = "${var.project_name}-mgn-igw"
  }
}

resource "aws_subnet" "staging" {
  count = var.use_existing_vpc ? 0 : 1

  vpc_id                  = aws_vpc.mgn[0].id
  cidr_block              = var.staging_subnet_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = var.use_public_ip_for_replication

  tags = {
    Name = "${var.project_name}-staging-subnet"
  }
}

resource "aws_route_table" "mgn" {
  count = var.use_existing_vpc ? 0 : 1

  vpc_id = aws_vpc.mgn[0].id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.mgn[0].id
  }

  tags = {
    Name = "${var.project_name}-mgn-rt"
  }
}

resource "aws_route_table_association" "staging" {
  count = var.use_existing_vpc ? 0 : 1

  subnet_id      = aws_subnet.staging[0].id
  route_table_id = aws_route_table.mgn[0].id
}

data "aws_availability_zones" "available" {
  state = "available"
}

# =============================================================================
# SECURITY GROUPS
# =============================================================================

# Security group for MGN replication servers
resource "aws_security_group" "mgn_replication" {
  name        = "${var.project_name}-mgn-replication-sg"
  description = "Security group for MGN replication servers"
  vpc_id      = local.vpc_id

  # Inbound: Allow replication traffic from source (port 1500)
  ingress {
    description = "MGN replication from source"
    from_port   = 1500
    to_port     = 1500
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Restrict to your source IP in production
  }

  # Outbound: Allow all (replication servers need to reach AWS services)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-mgn-replication-sg"
  }
}

# Security group for launched/migrated instances
resource "aws_security_group" "migrated_instances" {
  name        = "${var.project_name}-migrated-instances-sg"
  description = "Security group for migrated EC2 instances"
  vpc_id      = local.vpc_id

  # SSH access (restrict to your IP in production)
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP (if needed)
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS (if needed)
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-migrated-instances-sg"
  }
}

# =============================================================================
# IAM ROLES FOR MGN
# =============================================================================

# IAM role for MGN service (allows MGN to manage resources)
resource "aws_iam_role" "mgn_service" {
  name = "${var.project_name}-mgn-service-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "mgn.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-mgn-service-role"
  }
}

resource "aws_iam_role_policy_attachment" "mgn_service" {
  role       = aws_iam_role.mgn_service.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSApplicationMigrationServiceRolePolicy"
}

# IAM role for MGN replication servers
resource "aws_iam_role" "mgn_replication" {
  name = "${var.project_name}-mgn-replication-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-mgn-replication-role"
  }
}

resource "aws_iam_role_policy_attachment" "mgn_replication" {
  role       = aws_iam_role.mgn_replication.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSApplicationMigrationReplicationServerPolicy"
}

resource "aws_iam_instance_profile" "mgn_replication" {
  name = "${var.project_name}-mgn-replication-profile"
  role = aws_iam_role.mgn_replication.name
}

# IAM role for MGN conversion servers (used during launch)
resource "aws_iam_role" "mgn_conversion" {
  name = "${var.project_name}-mgn-conversion-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-mgn-conversion-role"
  }
}

resource "aws_iam_role_policy_attachment" "mgn_conversion" {
  role       = aws_iam_role.mgn_conversion.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSApplicationMigrationConversionServerPolicy"
}

resource "aws_iam_instance_profile" "mgn_conversion" {
  name = "${var.project_name}-mgn-conversion-profile"
  role = aws_iam_role.mgn_conversion.name
}

# IAM user for MGN agent (credentials used by agent on source VM)
resource "aws_iam_user" "mgn_agent" {
  name = "${var.project_name}-mgn-agent-user"

  tags = {
    Name = "${var.project_name}-mgn-agent-user"
  }
}

resource "aws_iam_user_policy_attachment" "mgn_agent" {
  user       = aws_iam_user.mgn_agent.name
  policy_arn = "arn:aws:iam::aws:policy/AWSApplicationMigrationAgentInstallationPolicy"
}

resource "aws_iam_access_key" "mgn_agent" {
  user = aws_iam_user.mgn_agent.name
}

# =============================================================================
# MGN SERVICE INITIALIZATION
# =============================================================================

# Initialize MGN service in the region (one-time setup)
resource "null_resource" "mgn_initialize" {
  provisioner "local-exec" {
    command = <<-EOT
      aws mgn initialize-service --region ${var.aws_region} 2>/dev/null || echo "MGN service already initialized"
    EOT
  }
}

# =============================================================================
# MGN REPLICATION CONFIGURATION TEMPLATE
# =============================================================================

resource "aws_mgn_replication_configuration_template" "main" {
  depends_on = [null_resource.mgn_initialize]

  # Replication server configuration
  replication_server_instance_type       = var.replication_server_instance_type
  use_dedicated_replication_server       = false
  associate_default_security_group       = false
  replication_servers_security_groups_ids = [aws_security_group.mgn_replication.id]

  # Network configuration
  staging_area_subnet_id = local.subnet_id
  create_public_ip       = var.use_public_ip_for_replication

  # Bandwidth throttling (0 = no throttling)
  bandwidth_throttling = var.bandwidth_throttling

  # EBS configuration for replicated disks
  default_large_staging_disk_type = "GP3"
  ebs_encryption                  = var.ebs_encryption_key_arn != "" ? "CUSTOM" : "DEFAULT"
  ebs_encryption_key_arn          = var.ebs_encryption_key_arn != "" ? var.ebs_encryption_key_arn : null

  # Data plane routing (PUBLIC_IP for internet-based replication)
  data_plane_routing = var.use_public_ip_for_replication ? "PUBLIC_IP" : "PRIVATE_IP"

  # Staging disk configuration
  staging_area_tags = {
    Name      = "${var.project_name}-staging-disk"
    ManagedBy = "MGN"
  }

  tags = {
    Name = "${var.project_name}-replication-template"
  }
}

# =============================================================================
# OUTPUTS - Agent download and instructions are in outputs.tf
# =============================================================================
