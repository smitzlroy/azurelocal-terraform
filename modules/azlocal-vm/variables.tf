# =============================================================================
# Azure Local VM Module - Input Variables
# =============================================================================
# This file defines all input variables for the Azure Local VM module.
# Variable naming follows the conventions from Microsoft's AKS Arc Terraform docs.
#
# Key Azure Local concepts:
# - Custom Location: The Azure Arc-enabled location representing your Azure Local cluster
# - Logical Network: The network resource in Azure Local (similar to VNet/Subnet in public Azure)
# - Gallery Image: VM images stored in Azure Local's local gallery
# - Arc Resource Bridge: The component that enables Azure Arc integration with Azure Local
# =============================================================================

# -----------------------------------------------------------------------------
# Required Variables - Core Azure Local Configuration
# -----------------------------------------------------------------------------

variable "resource_group_id" {
  description = <<-EOT
    The Azure Resource Manager ID of the resource group where VMs will be created.
    Use the full resource ID format: /subscriptions/{sub}/resourceGroups/{name}
    
    Example: /subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mylocal-rg
    
    NOTE: Unlike public Azure where you might use resource group name, Azure Local
    resources work better with full resource IDs for cross-resource references.
  EOT
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^/subscriptions/[a-f0-9-]+/resourceGroups/[a-zA-Z0-9-_().]+$", var.resource_group_id))
    error_message = "resource_group_id must be a valid Azure Resource Manager resource group ID."
  }
}

variable "custom_location_id" {
  description = <<-EOT
    The Azure Resource Manager ID of the Custom Location for your Azure Local cluster.
    
    The Custom Location is created during Azure Local deployment and represents your
    on-premises infrastructure in Azure. All Azure Local VMs must be deployed to a
    Custom Location.
    
    To find your Custom Location ID:
      az customlocation show --name "<name>" --resource-group "<rg>" --query id -o tsv
    
    Example: /subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.ExtendedLocation/customLocations/{name}
    
    IMPORTANT: This is a fundamental difference from public Azure - in Azure Local,
    resources are deployed to Custom Locations instead of Azure regions.
  EOT
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^/subscriptions/[a-f0-9-]+/resourceGroups/[^/]+/providers/Microsoft.ExtendedLocation/customLocations/[^/]+$", var.custom_location_id))
    error_message = "custom_location_id must be a valid Custom Location resource ID."
  }
}

variable "logical_network_id" {
  description = <<-EOT
    The Azure Resource Manager ID of the Azure Local Logical Network.
    
    CONCEPT MAPPING (Public Azure -> Azure Local):
    - VNet/Subnet -> Logical Network
    - In Azure Local, Logical Networks provide layer-2 connectivity to VMs
    - They can be configured with DHCP or static IP pools
    
    To find your Logical Network ID:
      az stack-hci-vm network lnet show --name "<name>" --resource-group "<rg>" --query id -o tsv
    
    Example: /subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.AzureStackHCI/logicalNetworks/{name}
    
    NOTE: Unlike public Azure VNets, Logical Networks in Azure Local map to the
    physical network infrastructure configured on your Azure Local cluster.
  EOT
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^/subscriptions/[a-f0-9-]+/resourceGroups/[^/]+/providers/Microsoft.AzureStackHCI/logicalNetworks/[^/]+$", var.logical_network_id))
    error_message = "logical_network_id must be a valid Azure Local Logical Network resource ID."
  }
}

variable "location" {
  description = <<-EOT
    The Azure region where the Azure Local cluster is registered.
    
    This should match the region used when your Azure Local cluster was registered
    with Azure Arc. The VMs are physically hosted on your Azure Local hardware,
    but their Azure resource metadata is stored in this region.
    
    Example: eastus, westeurope, australiaeast
  EOT
  type        = string
  nullable    = false
}

# -----------------------------------------------------------------------------
# VM Configuration Variables
# -----------------------------------------------------------------------------

variable "vm_name" {
  description = <<-EOT
    Base name for the VM(s). When using vm_count > 1, VMs will be named 
    {vm_name}-001, {vm_name}-002, etc. When using vm_instances map, this
    is used as a fallback prefix.
    
    Must follow Azure naming rules: 1-15 characters for Windows, 1-64 for Linux.
  EOT
  type        = string
  nullable    = false

  validation {
    condition     = length(var.vm_name) >= 1 && length(var.vm_name) <= 64
    error_message = "vm_name must be between 1 and 64 characters."
  }
}

variable "vm_count" {
  description = <<-EOT
    Number of identical VMs to create. Use this for simple scale-out scenarios.
    For more control over individual VMs, use the vm_instances variable instead.
    
    When vm_count > 0 and vm_instances is empty, creates vm_count identical VMs.
    When vm_instances is provided, vm_count is ignored.
  EOT
  type        = number
  default     = 1
  nullable    = false

  validation {
    condition     = var.vm_count >= 0 && var.vm_count <= 100
    error_message = "vm_count must be between 0 and 100."
  }
}

variable "vm_instances" {
  description = <<-EOT
    Map of VM instances with per-VM overrides. Use this for heterogeneous deployments.
    
    Each key is the VM name, and the value is an object with optional overrides:
    - size: Override the default vm_size for this specific VM
    - static_ip: Assign a specific static IP from the Logical Network
    - admin_username: Override the admin username (useful for mixed Linux/Windows)
    - tags: Additional tags specific to this VM
    
    Example:
    {
      "web-server-01" = {
        size      = "Standard_D4s_v3"
        static_ip = "192.168.1.10"
      }
      "web-server-02" = {
        size      = "Standard_D4s_v3"
        static_ip = "192.168.1.11"
      }
    }
    
    NOTE: When vm_instances is provided, vm_count is ignored.
  EOT
  type = map(object({
    size           = optional(string)
    static_ip      = optional(string)
    admin_username = optional(string)
    tags           = optional(map(string), {})
  }))
  default  = {}
  nullable = false
}

variable "vm_size" {
  description = <<-EOT
    Default VM size for all VMs. Can be overridden per-VM in vm_instances.
    
    Azure Local supports a subset of Azure VM sizes. Common sizes include:
    - Standard_D2s_v3, Standard_D4s_v3, Standard_D8s_v3
    - Standard_DS2_v2, Standard_DS3_v2
    
    Check your Azure Local configuration for available sizes.
  EOT
  type        = string
  default     = "Standard_D2s_v3"
  nullable    = false
}

# -----------------------------------------------------------------------------
# Image Configuration - Azure Local Gallery Images
# -----------------------------------------------------------------------------
# CONCEPT: Azure Local uses a local gallery to store VM images. These images
# can be sourced from Azure Marketplace, uploaded VHDs, or custom images.
# This is similar to Azure Compute Gallery but local to your Azure Local cluster.

variable "gallery_image_id" {
  description = <<-EOT
    The Azure Resource Manager ID of an Azure Local gallery image.
    
    Use EITHER gallery_image_id OR image_reference, not both.
    
    To list available gallery images:
      az stack-hci-vm image list --resource-group "<rg>" --query "[].id" -o tsv
    
    Example: /subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.AzureStackHCI/galleryImages/{name}
  EOT
  type        = string
  default     = null

  validation {
    condition     = var.gallery_image_id == null || can(regex("^/subscriptions/[a-f0-9-]+/resourceGroups/[^/]+/providers/Microsoft.AzureStackHCI/galleryImages/[^/]+$", var.gallery_image_id))
    error_message = "gallery_image_id must be a valid Azure Local gallery image resource ID."
  }
}

variable "image_reference" {
  description = <<-EOT
    Structured image reference for Azure Marketplace images available in Azure Local.
    
    Use EITHER gallery_image_id OR image_reference, not both.
    
    CONCEPT: Similar to public Azure, you can specify publisher/offer/sku/version.
    However, the image must be downloaded to your Azure Local cluster first.
    
    Example:
    {
      publisher = "Canonical"
      offer     = "UbuntuServer"
      sku       = "22_04-lts"
      version   = "latest"
    }
  EOT
  type = object({
    publisher = string
    offer     = string
    sku       = string
    version   = optional(string, "latest")
  })
  default = null
}

variable "os_type" {
  description = <<-EOT
    Operating system type: 'Linux' or 'Windows'.
    This determines which OS customization options are available.
  EOT
  type        = string
  nullable    = false

  validation {
    condition     = contains(["Linux", "Windows"], var.os_type)
    error_message = "os_type must be either 'Linux' or 'Windows'."
  }
}

# -----------------------------------------------------------------------------
# Authentication Variables
# -----------------------------------------------------------------------------

variable "admin_username" {
  description = <<-EOT
    Default administrator username for the VM(s).
    
    For Linux: Used for SSH access
    For Windows: Used for RDP/WinRM access
    
    Can be overridden per-VM in vm_instances.
  EOT
  type        = string
  default     = "azureadmin"
  nullable    = false

  validation {
    condition     = length(var.admin_username) >= 1 && length(var.admin_username) <= 64
    error_message = "admin_username must be between 1 and 64 characters."
  }
}

variable "ssh_public_key" {
  description = <<-EOT
    SSH public key for Linux VMs. Required when os_type is 'Linux'.
    
    Create an SSH key pair following Microsoft's guidance:
      ssh-keygen -t rsa -b 4096
    or
      az sshkey create --name "mySSHKey" --resource-group "<rg>"
    
    Provide the contents of your public key file (e.g., ~/.ssh/id_rsa.pub).
    
    NOTE: This follows the same pattern as the AKS Arc Terraform documentation
    for SSH key management.
  EOT
  type        = string
  default     = null
  sensitive   = true
}

variable "admin_password" {
  description = <<-EOT
    Administrator password for Windows VMs. Required when os_type is 'Windows'.
    
    Must meet Azure password complexity requirements:
    - At least 12 characters
    - Contains uppercase, lowercase, number, and special character
  EOT
  type        = string
  default     = null
  sensitive   = true
}

# -----------------------------------------------------------------------------
# Network Configuration
# -----------------------------------------------------------------------------

variable "static_ip" {
  description = <<-EOT
    Default static IP address for VMs. Only used when vm_count is used.
    For multiple VMs with static IPs, use vm_instances instead.
    
    The IP must be within the address range of the Logical Network.
    If null, DHCP is used (if the Logical Network supports it).
  EOT
  type        = string
  default     = null
}

variable "dns_servers" {
  description = <<-EOT
    List of DNS server IP addresses. If not specified, the Logical Network's
    DNS settings are used.
  EOT
  type        = list(string)
  default     = []
  nullable    = false
}

variable "nsg_id" {
  description = <<-EOT
    Optional Network Security Group ID to associate with the VM NICs.
    
    IMPORTANT: NSG support for Azure Local VMs was added in version 2506+.
    NSGs can be applied at the NIC level or Logical Network level.
    
    This module does NOT create NSGs - it only references an existing one.
    If your Azure Local version doesn't support NSGs, leave this null.
    
    Example: /subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.Network/networkSecurityGroups/{name}
  EOT
  type        = string
  default     = null
}

# -----------------------------------------------------------------------------
# OS Customization - Linux
# -----------------------------------------------------------------------------

variable "cloud_init" {
  description = <<-EOT
    Base64-encoded cloud-init configuration for Linux VMs.
    
    Cloud-init is the standard for customizing Linux VMs at first boot.
    Common uses:
    - SSH hardening
    - Package installation
    - User creation
    - Service configuration
    
    Example (before base64 encoding):
    #cloud-config
    package_update: true
    packages:
      - nginx
    ssh_pwauth: false
    
    To encode: base64 -w0 cloud-init.yaml
  EOT
  type        = string
  default     = null
  sensitive   = true
}

# -----------------------------------------------------------------------------
# OS Customization - Windows
# -----------------------------------------------------------------------------

variable "custom_data" {
  description = <<-EOT
    Base64-encoded custom data for Windows VMs.
    This can be a PowerShell script or other configuration data.
  EOT
  type        = string
  default     = null
  sensitive   = true
}

variable "timezone" {
  description = <<-EOT
    Windows timezone setting. 
    Example: "Pacific Standard Time", "UTC", "Eastern Standard Time"
  EOT
  type        = string
  default     = "UTC"
  nullable    = false
}

variable "winrm_enable" {
  description = <<-EOT
    Enable WinRM (Windows Remote Management) for remote PowerShell access.
    
    WARNING: Ensure proper network security (NSG rules, firewall) when enabling WinRM.
  EOT
  type        = bool
  default     = false
  nullable    = false
}

# -----------------------------------------------------------------------------
# Disk Configuration
# -----------------------------------------------------------------------------

variable "os_disk_size_gb" {
  description = <<-EOT
    Size of the OS disk in GB. If not specified, uses the image default.
    
    Minimum recommended sizes:
    - Linux: 30 GB
    - Windows: 127 GB
  EOT
  type        = number
  default     = null

  validation {
    condition     = var.os_disk_size_gb == null || (var.os_disk_size_gb >= 30 && var.os_disk_size_gb <= 4096)
    error_message = "os_disk_size_gb must be between 30 and 4096 GB."
  }
}

variable "os_disk_type" {
  description = <<-EOT
    Storage type for the OS disk.
    
    Options depend on your Azure Local storage configuration:
    - Standard_LRS: Standard HDD
    - Premium_LRS: Premium SSD (recommended for production)
  EOT
  type        = string
  default     = "Premium_LRS"
  nullable    = false

  validation {
    condition     = contains(["Standard_LRS", "Premium_LRS"], var.os_disk_type)
    error_message = "os_disk_type must be either 'Standard_LRS' or 'Premium_LRS'."
  }
}

variable "data_disks" {
  description = <<-EOT
    List of data disks to attach to each VM.
    
    Each disk object should contain:
    - size_gb: Disk size in GB
    - storage_type: "Standard_LRS" or "Premium_LRS"
    - caching: "None", "ReadOnly", or "ReadWrite"
    - lun: Logical Unit Number (0-63)
    
    Example:
    [
      {
        size_gb      = 128
        storage_type = "Premium_LRS"
        caching      = "ReadOnly"
        lun          = 0
      },
      {
        size_gb      = 256
        storage_type = "Premium_LRS"
        caching      = "None"
        lun          = 1
      }
    ]
  EOT
  type = list(object({
    size_gb      = number
    storage_type = optional(string, "Premium_LRS")
    caching      = optional(string, "None")
    lun          = number
  }))
  default  = []
  nullable = false

  validation {
    condition     = alltrue([for d in var.data_disks : d.size_gb >= 1 && d.size_gb <= 4096])
    error_message = "Each data disk size_gb must be between 1 and 4096 GB."
  }

  validation {
    condition     = alltrue([for d in var.data_disks : contains(["None", "ReadOnly", "ReadWrite"], d.caching)])
    error_message = "Data disk caching must be 'None', 'ReadOnly', or 'ReadWrite'."
  }
}

# -----------------------------------------------------------------------------
# Tags
# -----------------------------------------------------------------------------

variable "tags" {
  description = <<-EOT
    Map of tags to apply to all resources created by this module.
    
    Example:
    {
      Environment = "Production"
      Project     = "WebApp"
      Owner       = "Platform Team"
    }
  EOT
  type        = map(string)
  default     = {}
  nullable    = false
}
