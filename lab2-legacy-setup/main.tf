# main.tf - Legacy application infrastructure (simplified)
# This creates the "legacy" resources that students will import in Lab 2
#
# SIMPLE ARCHITECTURE: Single server, single AZ, no load balancing
# This represents a hastily-deployed legacy app. After importing to Terraform,
# students could evolve it to add multi-AZ, load balancing, auto scaling, etc.
#
# Resources created (6 total):
#   1. VPC
#   2. Public Subnet
#   3. Internet Gateway
#   4. Route Table
#   5. Route Table Association
#   6. Security Group
#   7. EC2 Instance

# -----------------------------------------------------------------------------
# Data Sources
# -----------------------------------------------------------------------------

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

# -----------------------------------------------------------------------------
# VPC
# -----------------------------------------------------------------------------

resource "aws_vpc" "legacy" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.student_id}-legacy-vpc"
  }
}

# -----------------------------------------------------------------------------
# Public Subnet (single AZ)
# -----------------------------------------------------------------------------

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.legacy.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, 1) # 10.0.1.0/24
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.student_id}-legacy-public"
  }
}

# -----------------------------------------------------------------------------
# Internet Gateway
# -----------------------------------------------------------------------------

resource "aws_internet_gateway" "legacy" {
  vpc_id = aws_vpc.legacy.id

  tags = {
    Name = "${var.student_id}-legacy-igw"
  }
}

# -----------------------------------------------------------------------------
# Route Table
# -----------------------------------------------------------------------------

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.legacy.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.legacy.id
  }

  tags = {
    Name = "${var.student_id}-legacy-rt"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# -----------------------------------------------------------------------------
# Security Group
# -----------------------------------------------------------------------------

resource "aws_security_group" "legacy" {
  name        = "${var.student_id}-legacy-sg"
  description = "Security group for legacy web server"
  vpc_id      = aws_vpc.legacy.id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.student_id}-legacy-sg"
  }
}

# -----------------------------------------------------------------------------
# EC2 Instance (single server - the "legacy" app)
# -----------------------------------------------------------------------------

resource "aws_instance" "legacy" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.legacy.id]

  user_data = <<-EOF
    #!/bin/bash
    dnf install -y httpd
    systemctl enable httpd
    systemctl start httpd

    # Create a simple legacy app page
    cat > /var/www/html/index.html << 'HTML'
    <!DOCTYPE html>
    <html>
    <head>
        <title>Legacy App - ${var.student_id}</title>
        <style>
            body { font-family: Arial, sans-serif; margin: 40px; background: #f5f5f5; }
            .container { background: white; padding: 30px; border-radius: 8px; max-width: 600px; margin: 0 auto; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
            h1 { color: #333; }
            .info { background: #e7f3ff; padding: 15px; border-radius: 4px; margin: 20px 0; }
            .warning { background: #fff3cd; padding: 15px; border-radius: 4px; margin: 20px 0; }
        </style>
    </head>
    <body>
        <div class="container">
            <h1>Legacy Application</h1>
            <div class="info">
                <strong>Status:</strong> Running<br>
                <strong>Student:</strong> ${var.student_id}<br>
                <strong>Deployed:</strong> Via AWS Console (simulated)
            </div>
            <div class="warning">
                <strong>Warning:</strong> This application has no infrastructure-as-code,
                no version control, and runs on a single server with no redundancy.
            </div>
            <p>Your mission: Import this infrastructure into Terraform management.</p>
        </div>
    </body>
    </html>
    HTML
  EOF

  tags = {
    Name = "${var.student_id}-legacy-server"
  }
}
