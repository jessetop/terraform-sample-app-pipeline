# main.tf - vSphere source VM discovery
#
# This stage discovers information about the source VM on ESXi.
# It creates no resources — only data sources for downstream stages.

# =============================================================================
# DATA SOURCES - ESXi environment and VM information
# =============================================================================

data "vsphere_datacenter" "dc" {
  name = "ha-datacenter"
}

data "vsphere_datastore" "datastore" {
  name          = var.datastore_name
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_virtual_machine" "source_vm" {
  name          = var.vm_name
  datacenter_id = data.vsphere_datacenter.dc.id
}

# =============================================================================
# LOCAL VALUES
# =============================================================================

locals {
  vm_ip = try(data.vsphere_virtual_machine.source_vm.guest_ip_addresses[0], "unknown")
}
