# network.tf - VPC and Networking Resources (imported)

resource "aws_vpc" "legacy" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.student_id}-legacy-vpc"
  }
}

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.legacy.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.student_id}-legacy-public-a"
  }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.legacy.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.student_id}-legacy-public-b"
  }
}

resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.legacy.id
  cidr_block        = "10.0.10.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "${var.student_id}-legacy-private-a"
  }
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.legacy.id
  cidr_block        = "10.0.20.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name = "${var.student_id}-legacy-private-b"
  }
}

resource "aws_internet_gateway" "legacy" {
  vpc_id = aws_vpc.legacy.id

  tags = {
    Name = "${var.student_id}-legacy-igw"
  }
}

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
