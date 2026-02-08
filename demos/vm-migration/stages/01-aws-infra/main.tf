# ======================================================================
# Stage 01 - AWS Landing Zone Infrastructure
# ======================================================================
# Creates the AWS resources needed before VM import:
#   - S3 bucket for VM disk images (encrypted, versioned, no public access)
#   - IAM vmimport role and policy for the VM Import/Export service
#   - VPC, subnet, internet gateway, and route table
#   - Security group for migrated instances
# ======================================================================

# ======================================================================
# S3 Bucket for VM Images
# ======================================================================

resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

resource "aws_s3_bucket" "vmimport" {
  bucket = "${var.project_name}-vmimport-${random_string.suffix.result}"

  tags = {
    Name = "${var.project_name}-vmimport"
  }
}

resource "aws_s3_bucket_versioning" "vmimport" {
  bucket = aws_s3_bucket.vmimport.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "vmimport" {
  bucket = aws_s3_bucket.vmimport.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "vmimport" {
  bucket = aws_s3_bucket.vmimport.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ======================================================================
# IAM Role and Policy for VM Import/Export Service
# ======================================================================

resource "aws_iam_role" "vmimport" {
  name = "${var.project_name}-vmimport"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "vmie.amazonaws.com"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "sts:ExternalId" = "vmimport"
          }
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-vmimport"
  }
}

resource "aws_iam_role_policy" "vmimport" {
  name = "${var.project_name}-vmimport"
  role = aws_iam_role.vmimport.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetBucketLocation",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:PutObject",
          "s3:GetBucketAcl"
        ]
        Resource = [
          aws_s3_bucket.vmimport.arn,
          "${aws_s3_bucket.vmimport.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:ModifySnapshotAttribute",
          "ec2:CopySnapshot",
          "ec2:RegisterImage",
          "ec2:Describe*"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:CreateGrant",
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:Encrypt",
          "kms:GenerateDataKey*",
          "kms:ReEncrypt*"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "license-manager:GetLicenseConfiguration",
          "license-manager:UpdateLicenseSpecificationsForResource",
          "license-manager:ListLicenseSpecifications"
        ]
        Resource = "*"
      }
    ]
  })
}

# ======================================================================
# VPC and Networking
# ======================================================================

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "migration" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

resource "aws_internet_gateway" "migration" {
  vpc_id = aws_vpc.migration.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

resource "aws_subnet" "migration" {
  vpc_id                  = aws_vpc.migration.id
  cidr_block              = var.subnet_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-subnet"
  }
}

resource "aws_route_table" "migration" {
  vpc_id = aws_vpc.migration.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.migration.id
  }

  tags = {
    Name = "${var.project_name}-rt"
  }
}

resource "aws_route_table_association" "migration" {
  subnet_id      = aws_subnet.migration.id
  route_table_id = aws_route_table.migration.id
}

# ======================================================================
# Security Group for Migrated Instances
# ======================================================================

resource "aws_security_group" "migrated_instances" {
  name        = "${var.project_name}-migrated-sg"
  description = "Security group for migrated VM instances"
  vpc_id      = aws_vpc.migration.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-migrated-sg"
  }
}
