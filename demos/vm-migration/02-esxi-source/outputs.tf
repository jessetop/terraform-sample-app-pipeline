# outputs.tf - Source VM information and migration instructions

output "vm_name" {
  description = "Name of the source VM"
  value       = data.vsphere_virtual_machine.source_vm.name
}

output "vm_id" {
  description = "VM ID in vSphere"
  value       = data.vsphere_virtual_machine.source_vm.id
}

output "vm_uuid" {
  description = "VM UUID"
  value       = data.vsphere_virtual_machine.source_vm.uuid
}

output "vm_guest_id" {
  description = "Guest OS identifier"
  value       = data.vsphere_virtual_machine.source_vm.guest_id
}

output "vm_ip_address" {
  description = "IP address of the VM (if VMware Tools is installed)"
  value       = local.vm_ip
}

output "vm_num_cpus" {
  description = "Number of CPUs"
  value       = data.vsphere_virtual_machine.source_vm.num_cpus
}

output "vm_memory_mb" {
  description = "Memory in MB"
  value       = data.vsphere_virtual_machine.source_vm.memory
}

output "vm_disks" {
  description = "Disk information"
  value = {
    count = length(data.vsphere_virtual_machine.source_vm.disks)
    disks = data.vsphere_virtual_machine.source_vm.disks
  }
}

output "datastore" {
  description = "Datastore where VM is stored"
  value       = data.vsphere_datastore.datastore.name
}

output "agent_install_script_path" {
  description = "Path to the generated agent installation script"
  value       = local_file.agent_install_script.filename
}

output "installation_instructions" {
  description = "Instructions for installing MGN agent on the source VM"
  value       = <<-EOT

    ============================================================
    MGN Agent Installation Instructions
    ============================================================

    Source VM: ${data.vsphere_virtual_machine.source_vm.name}
    IP Address: ${local.vm_ip}
    CPUs: ${data.vsphere_virtual_machine.source_vm.num_cpus}
    Memory: ${data.vsphere_virtual_machine.source_vm.memory} MB

    OPTION 1: Copy and run the generated script
    -------------------------------------------
    1. Copy the generated script to your VM:
       scp ${local_file.agent_install_script.filename} ${var.vm_ssh_user}@${local.vm_ip}:/tmp/

    2. SSH to the VM and run it:
       ssh ${var.vm_ssh_user}@${local.vm_ip}
       sudo /tmp/install-mgn-agent-generated.sh

    OPTION 2: Manual installation
    -------------------------------------------
    1. SSH to the source VM:
       ssh ${var.vm_ssh_user}@${local.vm_ip}

    2. Download the MGN agent:
       wget -O ./aws-replication-installer-init ${local.mgn_agent_url}
       chmod +x aws-replication-installer-init

    3. Run the installer (as root):
       sudo ./aws-replication-installer-init \
         --region ${var.aws_region} \
         --aws-access-key-id <ACCESS_KEY_FROM_01-aws-mgn-setup> \
         --aws-secret-access-key <SECRET_KEY_FROM_01-aws-mgn-setup> \
         --no-prompt

    4. Verify the agent:
       sudo systemctl status aws-replication-agent

    AFTER INSTALLATION:
    -------------------------------------------
    1. Monitor replication in AWS Console:
       https://${var.aws_region}.console.aws.amazon.com/mgn/home?region=${var.aws_region}#/sourceServers

    2. Wait for "Initial sync" to complete (can take hours for large disks)

    3. Launch test instance to verify migration

    4. Perform cutover when ready

    IF AGENT DOESN'T WORK:
    -------------------------------------------
    Use the fallback method: cd ../03-fallback-vmimport/

  EOT
}

output "network_test_commands" {
  description = "Commands to test network connectivity from source VM"
  value       = <<-EOT

    Run these commands on the source VM to verify network connectivity:

    # Test HTTPS to MGN endpoint (required)
    curl -v https://mgn.${var.aws_region}.amazonaws.com

    # Test S3 access (for agent download)
    curl -I ${local.mgn_agent_url}

    # Check if port 1500 can reach AWS (after agent install)
    # The replication server IP will be shown in MGN console
    # nc -zv <replication-server-ip> 1500

  EOT
}
