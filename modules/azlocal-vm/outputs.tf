# =============================================================================
# Azure Local VM Module - Outputs
# =============================================================================
# This file defines all outputs from the Azure Local VM module.
# These outputs provide the resource IDs and key information needed for
# subsequent automation or manual verification.
# =============================================================================

# -----------------------------------------------------------------------------
# VM Resource Outputs
# -----------------------------------------------------------------------------

output "vm_ids" {
  description = <<-EOT
    Map of VM names to their Azure Resource Manager IDs.
    
    These IDs can be used for:
    - Azure CLI commands: az stack-hci-vm show --ids <id>
    - Cross-referencing in other Terraform modules
    - Azure Policy assignments
  EOT
  value = {
    for name, vm in azapi_resource.vm : name => vm.id
  }
}

output "vm_names" {
  description = "List of created VM names."
  value       = keys(local.vm_map)
}

output "arc_machine_ids" {
  description = <<-EOT
    Map of VM names to their Arc Machine resource IDs.
    
    The Arc Machine is the Azure representation of the on-premises VM,
    enabling Azure management features like:
    - Azure Policy
    - Azure Monitor
    - Azure Update Manager
    - Microsoft Defender for Cloud
  EOT
  value = {
    for name, machine in azapi_resource.arc_machine : name => machine.id
  }
}

# -----------------------------------------------------------------------------
# Network Interface Outputs
# -----------------------------------------------------------------------------

output "nic_ids" {
  description = <<-EOT
    Map of VM names to their Network Interface resource IDs.
    
    Use these IDs to:
    - Attach NSGs (on Azure Local 2506+)
    - Query NIC details via CLI
    - Reference in other Terraform configurations
  EOT
  value = {
    for name, nic in azapi_resource.nic : name => nic.id
  }
}

output "private_ips" {
  description = <<-EOT
    Map of VM names to their private IP addresses.
    
    NOTE: For VMs using DHCP, the IP may not be immediately available
    after Terraform apply. Query the NIC resource for the actual assigned IP.
    
    For VMs with static IPs, this reflects the configured static IP.
  EOT
  value = {
    for name, config in local.vm_map : name => config.static_ip
  }
}

output "static_ips" {
  description = <<-EOT
    Map of VM names to their static IP addresses (only VMs with static IPs).
    VMs using DHCP are not included in this output.
  EOT
  value = {
    for name, config in local.vm_map : name => config.static_ip
    if config.static_ip != null
  }
}

# -----------------------------------------------------------------------------
# Data Disk Outputs
# -----------------------------------------------------------------------------

output "data_disk_ids" {
  description = <<-EOT
    Map of data disk keys to their resource IDs.
    Key format: {vm_name}-datadisk-{lun}
  EOT
  value = {
    for key, disk in azapi_resource.data_disk : key => disk.id
  }
}

# -----------------------------------------------------------------------------
# Computed Outputs for Convenience
# -----------------------------------------------------------------------------

output "resource_group_name" {
  description = "Name of the resource group where VMs are deployed."
  value       = local.resource_group_name
}

output "custom_location_id" {
  description = "The Custom Location ID used for deployment."
  value       = var.custom_location_id
}

output "logical_network_id" {
  description = "The Logical Network ID used for VM networking."
  value       = var.logical_network_id
}

output "admin_username" {
  description = "The default admin username for the VMs."
  value       = var.admin_username
}

output "os_type" {
  description = "The operating system type (Linux or Windows)."
  value       = var.os_type
}

# -----------------------------------------------------------------------------
# Connection Information
# -----------------------------------------------------------------------------

output "ssh_connection_commands" {
  description = <<-EOT
    SSH connection commands for Linux VMs.
    
    NOTE: You need network connectivity to the Azure Local Logical Network
    to connect to these VMs. This may require:
    - VPN connection to your on-premises network
    - Jump host/bastion in the same network
    - Direct network access
  EOT
  value = var.os_type == "Linux" ? {
    for name, config in local.vm_map : name => config.static_ip != null ?
    "ssh ${coalesce(config.admin_username, var.admin_username)}@${config.static_ip}" :
    "ssh ${coalesce(config.admin_username, var.admin_username)}@<DHCP_IP> # Query NIC for actual IP"
  } : {}
}

output "rdp_connection_info" {
  description = <<-EOT
    RDP connection information for Windows VMs.
    
    NOTE: You need network connectivity to the Azure Local Logical Network
    to connect to these VMs.
  EOT
  value = var.os_type == "Windows" ? {
    for name, config in local.vm_map : name => {
      ip       = config.static_ip != null ? config.static_ip : "<DHCP_IP>"
      username = coalesce(config.admin_username, var.admin_username)
    }
  } : {}
}

# -----------------------------------------------------------------------------
# Summary Output
# -----------------------------------------------------------------------------

output "deployment_summary" {
  description = "Summary of the Azure Local VM deployment."
  value = {
    total_vms          = length(local.vm_map)
    vm_names           = keys(local.vm_map)
    os_type            = var.os_type
    location           = var.location
    resource_group     = local.resource_group_name
    custom_location_id = var.custom_location_id
    logical_network_id = var.logical_network_id
    data_disks_per_vm  = length(var.data_disks)
    static_ip_count    = length([for c in local.vm_map : c if c.static_ip != null])
  }
}
