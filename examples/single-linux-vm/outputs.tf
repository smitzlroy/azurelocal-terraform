# =============================================================================
# Azure Local VM Example - Outputs
# =============================================================================
# These outputs provide the information needed to connect to and manage
# the deployed VM. They follow similar patterns to the AKS Arc Terraform
# example outputs.
# =============================================================================

# -----------------------------------------------------------------------------
# VM Information
# -----------------------------------------------------------------------------

output "vm_name" {
  description = "Name of the deployed VM."
  value       = var.vm_name
}

output "vm_id" {
  description = "Azure Resource Manager ID of the VM."
  value       = module.linux_vm.vm_ids[keys(module.linux_vm.vm_ids)[0]]
}

output "arc_machine_id" {
  description = <<-EOT
    Azure Arc Machine ID for the VM.
    
    The Arc Machine enables Azure management features:
    - Azure Policy
    - Azure Monitor
    - Azure Update Manager
    - Microsoft Defender for Cloud
  EOT
  value       = module.linux_vm.arc_machine_ids[keys(module.linux_vm.arc_machine_ids)[0]]
}

output "nic_id" {
  description = "Network Interface resource ID."
  value       = module.linux_vm.nic_ids[keys(module.linux_vm.nic_ids)[0]]
}

# -----------------------------------------------------------------------------
# Connection Information
# -----------------------------------------------------------------------------

output "admin_username" {
  description = "Administrator username for SSH access."
  value       = var.admin_username
}

output "private_ip" {
  description = <<-EOT
    Private IP address of the VM.
    
    NOTE: For VMs using DHCP, this may be null. Query the NIC resource
    after VM provisioning to get the assigned IP:
      az stack-hci-vm nic show --name "<nic-name>" --resource-group "<rg>"
    
    For VMs with static IPs, this reflects the configured IP.
  EOT
  value       = module.linux_vm.private_ips[keys(module.linux_vm.private_ips)[0]]
}

output "ssh_command" {
  description = <<-EOT
    SSH command to connect to the VM.
    
    PREREQUISITES for SSH access:
    1. Network connectivity to the Azure Local Logical Network
       (via VPN, jump host, or direct network access)
    2. Your private SSH key matching the public key used for deployment
    
    Example:
      ssh -i ~/.ssh/id_rsa azureadmin@<IP_ADDRESS>
  EOT
  value       = module.linux_vm.ssh_connection_commands[keys(module.linux_vm.ssh_connection_commands)[0]]
}

# -----------------------------------------------------------------------------
# Resource IDs for Reference
# -----------------------------------------------------------------------------

output "resource_group_id" {
  description = "Resource Group ID where VM is deployed."
  value       = var.resource_group_id
}

output "custom_location_id" {
  description = "Custom Location ID (Azure Local cluster)."
  value       = var.custom_location_id
}

output "logical_network_id" {
  description = "Logical Network ID used for VM networking."
  value       = var.logical_network_id
}

# -----------------------------------------------------------------------------
# Deployment Summary
# -----------------------------------------------------------------------------

output "deployment_summary" {
  description = "Summary of the deployment."
  value       = module.linux_vm.deployment_summary
}

# -----------------------------------------------------------------------------
# Next Steps
# -----------------------------------------------------------------------------

output "next_steps" {
  description = "Instructions for connecting to and validating the VM."
  value       = <<-EOT
    
    ╔══════════════════════════════════════════════════════════════════════════╗
    ║                     Azure Local VM Deployment Complete                    ║
    ╠══════════════════════════════════════════════════════════════════════════╣
    ║                                                                          ║
    ║  VALIDATE THE DEPLOYMENT:                                                ║
    ║                                                                          ║
    ║  1. Check VM status in Azure:                                            ║
    ║     az stack-hci-vm show --name "${var.vm_name}" \                       ║
    ║       --resource-group "<resource-group-name>"                           ║
    ║                                                                          ║
    ║  2. Check Arc machine status:                                            ║
    ║     az connectedmachine show --name "${var.vm_name}" \                   ║
    ║       --resource-group "<resource-group-name>"                           ║
    ║                                                                          ║
    ║  3. Get NIC IP address (for DHCP):                                       ║
    ║     az stack-hci-vm nic show --name "${var.vm_name}-001-nic" \           ║
    ║       --resource-group "<resource-group-name>" --query "properties"      ║
    ║                                                                          ║
    ║  CONNECT TO THE VM:                                                      ║
    ║                                                                          ║
    ║  Ensure you have network connectivity to the Logical Network, then:      ║
    ║     ssh -i <path-to-private-key> ${var.admin_username}@<VM_IP>           ║
    ║                                                                          ║
    ║  VERIFY CLOUD-INIT:                                                      ║
    ║                                                                          ║
    ║  After connecting, check cloud-init completed:                           ║
    ║     cat /var/log/cloud-init-complete.log                                 ║
    ║     sudo systemctl status fail2ban                                       ║
    ║                                                                          ║
    ╚══════════════════════════════════════════════════════════════════════════╝
  EOT
}
