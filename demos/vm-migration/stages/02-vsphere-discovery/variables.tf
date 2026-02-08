# variables.tf - Input variables for vSphere source VM discovery

variable "esxi_host" {
  description = "ESXi host IP address or hostname"
  type        = string
}

variable "esxi_username" {
  description = "ESXi username"
  type        = string
  default     = "root"
}

variable "esxi_password" {
  description = "ESXi password"
  type        = string
  sensitive   = true
}

variable "allow_unverified_ssl" {
  description = "Allow unverified SSL certificates for vSphere connection"
  type        = bool
  default     = true
}

variable "vm_name" {
  description = "Name of the VM to migrate"
  type        = string
}

variable "datastore_name" {
  description = "Name of the ESXi datastore"
  type        = string
  default     = "datastore1"
}
