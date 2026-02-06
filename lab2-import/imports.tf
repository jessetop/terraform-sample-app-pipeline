# imports.tf - Import declarations for the legacy application stack
#
# All resource IDs are defined as variables in terraform.tfvars.
# Discover the IDs using AWS CLI, update tfvars, then run:
#   terraform plan -generate-config-out=generated.tf

# =============================================================================
# NETWORK LAYER
# =============================================================================

import {
  to = aws_vpc.legacy
  id = var.vpc_id
}

import {
  to = aws_subnet.public_a
  id = var.subnet_public_a_id
}

import {
  to = aws_subnet.public_b
  id = var.subnet_public_b_id
}

import {
  to = aws_subnet.private_a
  id = var.subnet_private_a_id
}

import {
  to = aws_subnet.private_b
  id = var.subnet_private_b_id
}

import {
  to = aws_internet_gateway.legacy
  id = var.internet_gateway_id
}

import {
  to = aws_eip.nat
  id = var.eip_allocation_id
}

import {
  to = aws_nat_gateway.legacy
  id = var.nat_gateway_id
}

import {
  to = aws_route_table.public
  id = var.route_table_public_id
}

import {
  to = aws_route_table.private
  id = var.route_table_private_id
}

import {
  to = aws_route_table_association.public_a
  id = "${var.subnet_public_a_id}/${var.route_table_public_id}"
}

import {
  to = aws_route_table_association.public_b
  id = "${var.subnet_public_b_id}/${var.route_table_public_id}"
}

import {
  to = aws_route_table_association.private_a
  id = "${var.subnet_private_a_id}/${var.route_table_private_id}"
}

import {
  to = aws_route_table_association.private_b
  id = "${var.subnet_private_b_id}/${var.route_table_private_id}"
}

# =============================================================================
# SECURITY LAYER
# =============================================================================

import {
  to = aws_security_group.alb
  id = var.security_group_alb_id
}

import {
  to = aws_security_group.ec2
  id = var.security_group_ec2_id
}

# =============================================================================
# APPLICATION LAYER
# =============================================================================

import {
  to = aws_lb.legacy
  id = var.alb_arn
}

import {
  to = aws_lb_target_group.legacy
  id = var.target_group_arn
}

import {
  to = aws_lb_listener.http
  id = var.listener_arn
}

# =============================================================================
# COMPUTE LAYER
# =============================================================================

import {
  to = aws_launch_template.legacy
  id = var.launch_template_id
}

import {
  to = aws_autoscaling_group.legacy
  id = var.autoscaling_group_name
}
