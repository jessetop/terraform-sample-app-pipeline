# outputs.tf - Discovered VM information for downstream stages

output "vm_name" {
  description = "Name of the source VM"
  value       = data.vsphere_virtual_machine.source_vm.name
}

output "vm_uuid" {
  description = "UUID of the source VM"
  value       = data.vsphere_virtual_machine.source_vm.uuid
}

output "vm_guest_id" {
  description = "Guest OS identifier of the source VM"
  value       = data.vsphere_virtual_machine.source_vm.guest_id
}

output "num_cpus" {
  description = "Number of CPUs on the source VM"
  value       = data.vsphere_virtual_machine.source_vm.num_cpus
}

output "memory_mb" {
  description = "Memory in MB on the source VM"
  value       = data.vsphere_virtual_machine.source_vm.memory
}

output "disk_info" {
  description = "Disk information for the source VM"
  value = {
    count = length(data.vsphere_virtual_machine.source_vm.disks)
    disks = data.vsphere_virtual_machine.source_vm.disks
  }
}

output "ip_address" {
  description = "IP address of the source VM"
  value       = local.vm_ip
}

output "esxi_host" {
  description = "ESXi host address"
  value       = var.esxi_host
}

output "datastore_name" {
  description = "ESXi datastore name"
  value       = data.vsphere_datastore.datastore.name
}
