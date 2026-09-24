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
    interpreter = ["PowerShell", "-Command"]
    command = <<-EOT
      $ErrorActionPreference = "Stop"

      Write-Host "=============================================="
      Write-Host "Exporting VM: ${local.vm_name}"
      Write-Host "From ESXi host: ${local.esxi_host}"
      Write-Host "=============================================="

      # Check ovftool is installed
      if (-not (Get-Command ovftool -ErrorAction SilentlyContinue)) {
        Write-Error "ERROR: ovftool not found in PATH"
        Write-Host "Download from: https://developer.vmware.com/web/tool/ovf/"
        exit 1
      }

      ovftool --version

      # Create output directory
      New-Item -ItemType Directory -Force -Path "${var.export_dir}" | Out-Null

      # Export VM to OVA (VM should be powered off for clean export)
      ovftool --noSSLVerify --diskMode=thin "vi://${var.esxi_username}:${var.esxi_password}@${local.esxi_host}/${local.vm_name}" "${local.ova_path}"

      if ($LASTEXITCODE -ne 0) {
        Write-Error "ovftool export failed with exit code $LASTEXITCODE"
        exit $LASTEXITCODE
      }

      Write-Host ""
      Write-Host "Export complete: ${local.ova_path}"
      Get-Item "${local.ova_path}" | Select-Object Name, Length
    EOT
  }
}
