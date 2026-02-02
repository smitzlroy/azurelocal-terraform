# =============================================================================
# Azure Local VM Example - Input Variables
# =============================================================================
# These variables follow the naming conventions from Microsoft's AKS Arc
# Terraform documentation, making the experience familiar for users who
# have deployed AKS Arc clusters.
#
# For reference: https://learn.microsoft.com/en-us/azure/aks/aksarc/create-clusters-terraform
# =============================================================================

# -----------------------------------------------------------------------------
# Azure Subscription and Authentication
# -----------------------------------------------------------------------------

variable "subscription_id" {
  description = <<-EOT
    The Azure subscription ID where your Azure Local cluster is registered.
    
    Get this from your infrastructure administrator or run:
      az account show --query id -o tsv
    
    This follows the same pattern as the AKS Arc Terraform documentation.
  EOT
  type        = string
  nullable    = false
}

# -----------------------------------------------------------------------------
# Azure Local Infrastructure IDs
# -----------------------------------------------------------------------------
# These IDs must be obtained from your Azure Local infrastructure administrator.
# They represent resources that are created during Azure Local cluster deployment.

variable "resource_group_id" {
  description = <<-EOT
    The full Azure Resource Manager ID of the resource group.
    
    Format: /subscriptions/{subscription-id}/resourceGroups/{resource-group-name}
    
    Get this by running:
      az group show --name "<rg-name>" --query id -o tsv
  EOT
  type        = string
  nullable    = false
}

variable "custom_location_id" {
  description = <<-EOT
    The Azure Resource Manager ID of the Custom Location for your Azure Local cluster.
    
    The Custom Location is created during Azure Local deployment and represents
    your on-premises infrastructure in Azure. This is analogous to specifying
    an Azure region for public Azure resources.
    
    Get this from your infrastructure administrator or run:
      az customlocation show --name "<name>" --resource-group "<rg>" --query id -o tsv
  EOT
  type        = string
  nullable    = false
}

variable "logical_network_id" {
  description = <<-EOT
    The Azure Resource Manager ID of the Azure Local Logical Network.
    
    Logical Networks in Azure Local serve a similar purpose to VNets/Subnets
    in public Azure. They provide layer-2 connectivity for your VMs.
    
    Get this from your infrastructure administrator or run:
      az stack-hci-vm network lnet show --name "<name>" --resource-group "<rg>" --query id -o tsv
  EOT
  type        = string
  nullable    = false
}

variable "location" {
  description = <<-EOT
    The Azure region where your Azure Local cluster is registered.
    
    Example: eastus, westeurope, australiaeast
    
    This should match the region used during Azure Local cluster registration.
  EOT
  type        = string
  nullable    = false
}

# -----------------------------------------------------------------------------
# VM Configuration
# -----------------------------------------------------------------------------

variable "vm_name" {
  description = <<-EOT
    Name for the Linux VM.
    
    Must follow Azure naming rules: 1-64 characters for Linux.
  EOT
  type        = string
  default     = "mylinuxvm"
  nullable    = false
}

variable "vm_size" {
  description = <<-EOT
    VM size. Check your Azure Local configuration for available sizes.
    
    NOTE: Azure Local uses "Custom" VM size with explicit processors and memory.
    This variable is maintained for compatibility reference.
    
    Common sizes: Standard_D2s_v3, Standard_D4s_v3, Standard_D8s_v3
  EOT
  type        = string
  default     = "Standard_D2s_v3"
  nullable    = false
}

variable "vm_processors" {
  description = <<-EOT
    Number of virtual processors (vCPUs) for the VM.
    
    Azure Local uses explicit processor count rather than predefined VM sizes.
  EOT
  type        = number
  default     = 2
  nullable    = false
}

variable "vm_memory_mb" {
  description = <<-EOT
    Amount of memory in megabytes for the VM.
    
    Common values: 4096 (4 GB), 8192 (8 GB), 16384 (16 GB)
  EOT
  type        = number
  default     = 8192
  nullable    = false
}

variable "admin_username" {
  description = <<-EOT
    Administrator username for SSH access.
    
    This follows the same pattern as AKS Arc node access.
  EOT
  type        = string
  default     = "azureadmin"
  nullable    = false
}

variable "ssh_public_key" {
  description = <<-EOT
    SSH public key for authentication.
    
    Create an SSH key pair following Microsoft's guidance:
      ssh-keygen -t rsa -b 4096
    or
      az sshkey create --name "mySSHKey" --resource-group "<rg>"
    
    Provide the contents of your public key file (e.g., ~/.ssh/id_rsa.pub).
    
    IMPORTANT: SSH keys are essential for troubleshooting and log collection.
    Save your private key file securely.
  EOT
  type        = string
  nullable    = false
  sensitive   = true
}

# -----------------------------------------------------------------------------
# Image Configuration
# -----------------------------------------------------------------------------

variable "gallery_image_id" {
  description = <<-EOT
    The Azure Resource Manager ID of the Azure Local gallery image.
    
    This is a Linux image that has been downloaded to your Azure Local cluster.
    
    To list available images:
      az stack-hci-vm image list --resource-group "<rg>" --query "[].id" -o tsv
    
    Example: /subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.AzureStackHCI/galleryImages/ubuntu-22.04-lts
  EOT
  type        = string
  nullable    = false
}

# -----------------------------------------------------------------------------
# Network Configuration (Optional)
# -----------------------------------------------------------------------------

variable "static_ip" {
  description = <<-EOT
    Optional static IP address from the Logical Network's IP pool.
    
    If not specified, DHCP is used (if the Logical Network supports it).
    The IP must be within the Logical Network's address range.
  EOT
  type        = string
  default     = null
}

variable "dns_servers" {
  description = <<-EOT
    Optional list of DNS server IP addresses.
    
    If not specified, uses the Logical Network's DNS configuration.
  EOT
  type        = list(string)
  default     = []
}

# -----------------------------------------------------------------------------
# Tags
# -----------------------------------------------------------------------------

variable "tags" {
  description = "Tags to apply to all resources."
  type        = map(string)
  default = {
    Environment = "Development"
    ManagedBy   = "Terraform"
    Example     = "single-linux-vm"
  }
}
