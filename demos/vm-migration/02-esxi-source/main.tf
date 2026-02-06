# main.tf - ESXi source VM information gathering
#
# This configuration:
# 1. Connects to ESXi and retrieves VM information
# 2. Outputs VM details needed for migration
# 3. Provides scripts and instructions for MGN agent installation

# =============================================================================
# DATA SOURCES - Get information about the ESXi environment and VM
# =============================================================================

# For standalone ESXi, the datacenter is always "ha-datacenter"
data "vsphere_datacenter" "dc" {
  name = "ha-datacenter"
}

# Get the default datastore
data "vsphere_datastore" "datastore" {
  name          = var.datastore_name != "" ? var.datastore_name : "datastore1"
  datacenter_id = data.vsphere_datacenter.dc.id
}

# Get information about the VM to migrate
data "vsphere_virtual_machine" "source_vm" {
  name          = var.vm_name
  datacenter_id = data.vsphere_datacenter.dc.id
}

# =============================================================================
# LOCAL VALUES
# =============================================================================

locals {
  vm_ip = try(data.vsphere_virtual_machine.source_vm.guest_ip_addresses[0], "unknown")

  # MGN agent download URL
  mgn_agent_url = "https://aws-application-migration-service-${var.aws_region}.s3.${var.aws_region}.amazonaws.com/latest/linux/aws-replication-installer-init"

  # Agent install script content
  agent_install_script = <<-EOT
    #!/bin/bash
    set -e

    echo "=== MGN Agent Installation Script ==="
    echo "Target: ${var.vm_name}"
    echo "Region: ${var.aws_region}"
    echo ""

    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
      echo "Please run as root (sudo)"
      exit 1
    fi

    # Check network connectivity to AWS
    echo "Checking network connectivity to AWS MGN endpoint..."
    if ! curl -s --connect-timeout 5 https://mgn.${var.aws_region}.amazonaws.com > /dev/null; then
      echo "ERROR: Cannot reach AWS MGN endpoint. Check network/firewall settings."
      echo "Required: Outbound TCP 443 to mgn.${var.aws_region}.amazonaws.com"
      exit 1
    fi
    echo "Network connectivity OK"

    # Download agent installer
    echo "Downloading MGN agent installer..."
    wget -O /tmp/aws-replication-installer-init "${local.mgn_agent_url}"
    chmod +x /tmp/aws-replication-installer-init

    # Install the agent
    echo "Installing MGN agent..."
    /tmp/aws-replication-installer-init \
      --region ${var.aws_region} \
      --aws-access-key-id '${var.mgn_agent_access_key_id}' \
      --aws-secret-access-key '${var.mgn_agent_secret_access_key}' \
      --no-prompt

    # Verify installation
    echo ""
    echo "Verifying agent installation..."
    if systemctl is-active --quiet aws-replication-agent; then
      echo "SUCCESS: MGN agent is running"
      systemctl status aws-replication-agent --no-pager
    else
      echo "WARNING: Agent may not be running. Check logs:"
      echo "  journalctl -u aws-replication-agent"
    fi

    echo ""
    echo "=== Installation Complete ==="
    echo "Monitor replication progress at:"
    echo "https://${var.aws_region}.console.aws.amazon.com/mgn/home?region=${var.aws_region}#/sourceServers"
  EOT
}

# =============================================================================
# GENERATE AGENT INSTALLATION SCRIPT
# =============================================================================

resource "local_file" "agent_install_script" {
  content  = local.agent_install_script
  filename = "${path.module}/scripts/install-mgn-agent-generated.sh"
  file_permission = "0755"
}

# =============================================================================
# ADDITIONAL VARIABLE (needed for datastore lookup)
# =============================================================================

variable "datastore_name" {
  description = "Name of the ESXi datastore (default: datastore1)"
  type        = string
  default     = ""
}
