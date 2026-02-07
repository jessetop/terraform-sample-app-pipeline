# network.tf - VPC and Networking Resources (imported)

resource "aws_vpc" "legacy" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.student_id}-legacy-vpc"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.legacy.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.student_id}-legacy-public"
  }
}

resource "aws_internet_gateway" "legacy" {
  vpc_id = aws_vpc.legacy.id

  tags = {
    Name = "${var.student_id}-legacy-igw"
  }
}

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
