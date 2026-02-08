# outputs.tf - Exported values for downstream stages

output "ova_path" {
  description = "Local path to the exported OVA file"
  value       = local.ova_path
}

output "ova_filename" {
  description = "Filename of the exported OVA"
  value       = "${local.vm_name}.ova"
}

output "vm_name" {
  description = "Name of the exported VM"
  value       = local.vm_name
}
