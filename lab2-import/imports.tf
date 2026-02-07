# imports.tf - Import blocks for legacy application (simplified)
#
# This file declares the 7 resources to import. After running
# terraform plan -generate-config-out=generated.tf, Terraform will
# create HCL configuration for each resource.
#
# Resources to import:
#   1. VPC
#   2. Subnet
#   3. Internet Gateway
#   4. Route Table
#   5. Route Table Association
#   6. Security Group
#   7. EC2 Instance

# =============================================================================
# NETWORK LAYER
# =============================================================================

import {
  to = aws_vpc.legacy
  id = var.vpc_id
}

import {
  to = aws_subnet.public
  id = var.subnet_id
}

import {
  to = aws_internet_gateway.legacy
  id = var.internet_gateway_id
}

import {
  to = aws_route_table.public
  id = var.route_table_id
}

# Route table association uses composite ID: subnet-id/route-table-id
import {
  to = aws_route_table_association.public
  id = "${var.subnet_id}/${var.route_table_id}"
}

# =============================================================================
# SECURITY LAYER
# =============================================================================

import {
  to = aws_security_group.legacy
  id = var.security_group_id
}

# =============================================================================
# COMPUTE LAYER
# =============================================================================

import {
  to = aws_instance.legacy
  id = var.instance_id
}
