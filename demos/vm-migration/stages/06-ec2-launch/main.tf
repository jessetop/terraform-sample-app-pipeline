# main.tf - Launch EC2 instance from imported AMI
#
# This stage is pure HCL — no scripts needed.

# =============================================================================
# REMOTE STATE - Read infrastructure and AMI from prior stages
# =============================================================================

data "terraform_remote_state" "aws_infra" {
  backend = "s3"
  config = {
    bucket = var.state_bucket
    key    = "vm-migration/aws-infra/terraform.tfstate"
    region = var.aws_region
  }
}

data "terraform_remote_state" "vm_import" {
  backend = "s3"
  config = {
    bucket = var.state_bucket
    key    = "vm-migration/vm-import/terraform.tfstate"
    region = var.aws_region
  }
}

locals {
  subnet_id         = data.terraform_remote_state.aws_infra.outputs.subnet_id
  security_group_id = data.terraform_remote_state.aws_infra.outputs.security_group_id
  ami_id            = data.terraform_remote_state.vm_import.outputs.ami_id
}

# =============================================================================
# EC2 INSTANCE - Launch migrated VM
# =============================================================================

resource "aws_instance" "migrated" {
  ami                    = local.ami_id
  instance_type          = var.instance_type
  subnet_id              = local.subnet_id
  vpc_security_group_ids = [local.security_group_id]
  key_name               = var.key_pair_name != "" ? var.key_pair_name : null

  tags = {
    Name = "migrated-vm"
  }
}

# =============================================================================
# ELASTIC IP - Public IP for the migrated instance
# =============================================================================

resource "aws_eip" "migrated" {
  instance = aws_instance.migrated.id

  tags = {
    Name = "migrated-vm-eip"
  }
}
