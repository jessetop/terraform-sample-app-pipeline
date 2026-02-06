# main.tf - Legacy application infrastructure
# This creates the "legacy" resources that students will import in Lab 2
#
# IMPORTANT: After running terraform apply, close this folder and pretend
# it doesn't exist. Your job in Lab 2 is to reverse-engineer and import
# these resources as if they were created manually years ago.

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
# Subnets
# -----------------------------------------------------------------------------

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.legacy.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, 1)  # 10.0.1.0/24
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.student_id}-legacy-public-a"
  }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.legacy.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, 2)  # 10.0.2.0/24
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.student_id}-legacy-public-b"
  }
}

resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.legacy.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 10)  # 10.0.10.0/24
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "${var.student_id}-legacy-private-a"
  }
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.legacy.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 20)  # 10.0.20.0/24
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name = "${var.student_id}-legacy-private-b"
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
# NAT Gateway
# -----------------------------------------------------------------------------

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${var.student_id}-legacy-nat-eip"
  }
}

resource "aws_nat_gateway" "legacy" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_a.id

  tags = {
    Name = "${var.student_id}-legacy-nat"
  }

  depends_on = [aws_internet_gateway.legacy]
}

# -----------------------------------------------------------------------------
# Route Tables
# -----------------------------------------------------------------------------

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.legacy.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.legacy.id
  }

  tags = {
    Name = "${var.student_id}-legacy-public-rt"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.legacy.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.legacy.id
  }

  tags = {
    Name = "${var.student_id}-legacy-private-rt"
  }
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private.id
}

# -----------------------------------------------------------------------------
# Security Groups
# -----------------------------------------------------------------------------

resource "aws_security_group" "alb" {
  name        = "${var.student_id}-legacy-alb-sg"
  description = "Security group for legacy ALB"
  vpc_id      = aws_vpc.legacy.id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
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
    Name = "${var.student_id}-legacy-alb-sg"
  }
}

resource "aws_security_group" "ec2" {
  name        = "${var.student_id}-legacy-ec2-sg"
  description = "Security group for legacy EC2 instances"
  vpc_id      = aws_vpc.legacy.id

  ingress {
    description     = "HTTP from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.student_id}-legacy-ec2-sg"
  }
}

# -----------------------------------------------------------------------------
# Application Load Balancer
# -----------------------------------------------------------------------------

resource "aws_lb" "legacy" {
  name               = "${var.student_id}-legacy-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id]

  tags = {
    Name = "${var.student_id}-legacy-alb"
  }
}

resource "aws_lb_target_group" "legacy" {
  name     = "${var.student_id}-legacy-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.legacy.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  tags = {
    Name = "${var.student_id}-legacy-tg"
  }
}

resource "aws_lb_listener" "legacy" {
  load_balancer_arn = aws_lb.legacy.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.legacy.arn
  }

  tags = {
    Name = "${var.student_id}-legacy-listener"
  }
}

# -----------------------------------------------------------------------------
# Launch Template & Auto Scaling Group
# -----------------------------------------------------------------------------

resource "aws_launch_template" "legacy" {
  name          = "${var.student_id}-legacy-lt"
  image_id      = data.aws_ami.amazon_linux_2023.id
  instance_type = var.instance_type

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.ec2.id]
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    dnf install -y httpd git
    systemctl enable httpd
    systemctl start httpd

    # Clone 2048 game (small repo, fast download)
    git clone https://github.com/gabrielecirulli/2048.git /tmp/2048
    cp -r /tmp/2048/* /var/www/html/

    # Add instance info to the page
    echo "<!-- Instance: $(hostname) | Student: ${var.student_id} | AZ: $(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone) -->" >> /var/www/html/index.html
  EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.student_id}-legacy-instance"
    }
  }

  tags = {
    Name = "${var.student_id}-legacy-lt"
  }
}

resource "aws_autoscaling_group" "legacy" {
  name                = "${var.student_id}-legacy-asg"
  desired_capacity    = 2
  max_size            = 4
  min_size            = 1
  target_group_arns   = [aws_lb_target_group.legacy.arn]
  vpc_zone_identifier = [aws_subnet.private_a.id, aws_subnet.private_b.id]

  launch_template {
    id      = aws_launch_template.legacy.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.student_id}-legacy-instance"
    propagate_at_launch = true
  }

  tag {
    key                 = "Student"
    value               = var.student_id
    propagate_at_launch = true
  }
}
