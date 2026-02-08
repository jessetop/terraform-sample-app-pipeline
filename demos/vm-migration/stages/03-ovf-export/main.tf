# main.tf - Export VM from ESXi using ovftool
#
# This stage uses local-exec because no Terraform resource exists for ovftool.
# It reads the VM name and ESXi host from Stage 02 remote state.

# =============================================================================
# REMOTE STATE - Read VM details from Stage 02
# =============================================================================

data "terraform_remote_state" "vsphere_discovery" {
  backend = "s3"
  config = {
    bucket = var.state_bucket
    key    = "vm-migration/vsphere-discovery/terraform.tfstate"
    region = "us-east-1"
  }
}

locals {
  vm_name   = data.terraform_remote_state.vsphere_discovery.outputs.vm_name
  esxi_host = data.terraform_remote_state.vsphere_discovery.outputs.esxi_host
  ova_path  = "${var.export_dir}/${local.vm_name}.ova"
}

# =============================================================================
# OVF EXPORT - Export VM to OVA using ovftool
# =============================================================================

resource "null_resource" "ovf_export" {
  triggers = {
    vm_name   = local.vm_name
    esxi_host = local.esxi_host
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e

      echo "=============================================="
      echo "Exporting VM: ${local.vm_name}"
      echo "From ESXi host: ${local.esxi_host}"
      echo "=============================================="

      # Check ovftool is installed
      if ! command -v ovftool &> /dev/null; then
        echo "ERROR: ovftool not found in PATH"
        echo "Download from: https://developer.vmware.com/web/tool/ovf/"
        exit 1
      fi

      ovftool --version

      # Create output directory
      mkdir -p "${var.export_dir}"

      # Export VM to OVA (VM should be powered off for clean export)
      ovftool \
        --noSSLVerify \
        --diskMode=thin \
        "vi://${var.esxi_username}:${var.esxi_password}@${local.esxi_host}/${local.vm_name}" \
        "${local.ova_path}"

      echo ""
      echo "Export complete: ${local.ova_path}"
      ls -lh "${local.ova_path}"
    EOT
  }
}
