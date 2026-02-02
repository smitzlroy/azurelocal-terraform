# =============================================================================
# Azure Local VM Module - Main Configuration
# =============================================================================
# This module creates Azure Local VMs using the azapi provider for stack-hci-vm
# resources. Azure Local VMs are managed through Azure Arc and deployed to a
# Custom Location on your Azure Local cluster.
#
# ARCHITECTURE OVERVIEW:
# ┌─────────────────────────────────────────────────────────────────────────┐
# │                           Azure (Control Plane)                         │
# │  ┌─────────────┐    ┌──────────────────┐    ┌─────────────────────┐    │
# │  │  Resource   │    │ Custom Location  │    │   Arc Resource      │    │
# │  │   Group     │◄───│  (Azure Local)   │◄───│     Bridge          │    │
# │  └─────────────┘    └──────────────────┘    └─────────────────────┘    │
# └─────────────────────────────────────────────────────────────────────────┘
#                                    │
#                                    ▼
# ┌─────────────────────────────────────────────────────────────────────────┐
# │                    Azure Local Cluster (Data Plane)                     │
# │  ┌─────────────┐    ┌──────────────────┐    ┌─────────────────────┐    │
# │  │   VM(s)     │◄───│  Logical Network │◄───│   Gallery Images    │    │
# │  │  + NICs     │    │  (Layer 2/SDN)   │    │   (Local Storage)   │    │
# │  └─────────────┘    └──────────────────┘    └─────────────────────┘    │
# └─────────────────────────────────────────────────────────────────────────┘
#
# KEY DIFFERENCES FROM PUBLIC AZURE:
# - VMs run on Azure Local hardware, not Azure datacenters
# - Logical Networks replace VNets (they map to physical/SDN networks)
# - Gallery Images are stored locally, not in Azure regions
# - Custom Location is required (represents your Azure Local cluster)
# - Resources are managed via Azure Arc (hybrid management)
# =============================================================================

# -----------------------------------------------------------------------------
# Local Values - Computed configurations
# -----------------------------------------------------------------------------

locals {
  # Extract resource group name from ID
  resource_group_name = element(split("/", var.resource_group_id), length(split("/", var.resource_group_id)) - 1)

  # Determine which VM configuration to use: vm_instances (map) or vm_count (simple)
  use_vm_instances = length(var.vm_instances) > 0

  # Build the effective VM map
  # If vm_instances is provided, use it directly
  # Otherwise, generate a map from vm_count
  vm_map = local.use_vm_instances ? var.vm_instances : {
    for i in range(var.vm_count) : format("%s-%03d", var.vm_name, i + 1) => {
      size           = null
      static_ip      = var.vm_count == 1 ? var.static_ip : null
      admin_username = null
      tags           = {}
    }
  }

  # VM hardware profile - Azure Local uses Custom vmSize with explicit values
  vm_processors = var.vm_processors
  vm_memory_mb  = var.vm_memory_mb

  # Validate that exactly one image source is provided
  has_gallery_image   = var.gallery_image_id != null
  has_image_reference = var.image_reference != null
  image_source_count  = (local.has_gallery_image ? 1 : 0) + (local.has_image_reference ? 1 : 0)

  # Common tags to apply to all resources
  common_tags = merge(var.tags, {
    "CreatedBy" = "Terraform"
    "Module"    = "azlocal-vm"
  })
}

# -----------------------------------------------------------------------------
# Validation - Ensure proper configuration
# -----------------------------------------------------------------------------

# Validate that exactly one image source is provided
resource "terraform_data" "validate_image_source" {
  lifecycle {
    precondition {
      condition     = local.image_source_count == 1
      error_message = "You must provide exactly one of 'gallery_image_id' or 'image_reference', not both or neither."
    }
  }
}

# Validate Linux VMs have SSH key
resource "terraform_data" "validate_linux_auth" {
  count = var.os_type == "Linux" ? 1 : 0

  lifecycle {
    precondition {
      condition     = var.ssh_public_key != null && var.ssh_public_key != ""
      error_message = "ssh_public_key is required when os_type is 'Linux'."
    }
  }
}

# Validate Windows VMs have password
resource "terraform_data" "validate_windows_auth" {
  count = var.os_type == "Windows" ? 1 : 0

  lifecycle {
    precondition {
      condition     = var.admin_password != null && var.admin_password != ""
      error_message = "admin_password is required when os_type is 'Windows'."
    }
  }
}

# -----------------------------------------------------------------------------
# Network Interfaces (NICs) - One per VM
# -----------------------------------------------------------------------------
# CONCEPT: In Azure Local, NICs connect VMs to Logical Networks.
# This is similar to public Azure NICs connecting to Subnets, but:
# - The Logical Network ID is used instead of subnet ID
# - Static IPs come from the Logical Network's IP pool
# - NSG attachment is optional and requires Azure Local 2506+

resource "azapi_resource" "nic" {
  for_each = local.vm_map

  type      = "Microsoft.AzureStackHCI/networkInterfaces@2024-01-01"
  name      = "${each.key}-nic"
  location  = var.location
  parent_id = var.resource_group_id

  # Azure Local resources require Extended Location (Custom Location)
  # This is a key difference from public Azure resources
  # Use schema_validation_enabled = false for Azure Local resources
  # as the azapi provider schema may not fully match Azure Local API
  schema_validation_enabled = false

  body = {
    extendedLocation = {
      type = "CustomLocation"
      name = var.custom_location_id
    }
    properties = {
      # Attach NIC to the Logical Network
      # In Azure Local, this replaces the subnet configuration from public Azure
      ipConfigurations = [
        {
          name = "ipconfig1"
          properties = merge(
            {
              subnet = {
                id = var.logical_network_id
              }
            },
            # Only include privateIPAddress if static IP is specified
            each.value.static_ip != null ? {
              privateIPAddress = each.value.static_ip
            } : {}
          )
        }
      ]
      # DNS servers override (optional)
      dnsSettings = length(var.dns_servers) > 0 ? {
        dnsServers = var.dns_servers
      } : null
    }
    tags = merge(local.common_tags, each.value.tags, {
      VMName = each.key
    })
  }

  depends_on = [
    terraform_data.validate_image_source
  ]
}

# -----------------------------------------------------------------------------
# Data Disks (Optional) - Created separately for each VM
# -----------------------------------------------------------------------------
# CONCEPT: Data disks in Azure Local work similarly to public Azure but are
# stored on the Azure Local cluster's storage infrastructure.

resource "azapi_resource" "data_disk" {
  for_each = {
    for pair in flatten([
      for vm_name, vm_config in local.vm_map : [
        for disk in var.data_disks : {
          key     = "${vm_name}-datadisk-${disk.lun}"
          vm_name = vm_name
          disk    = disk
          vm_tags = vm_config.tags
        }
      ]
    ]) : pair.key => pair
  }

  type      = "Microsoft.AzureStackHCI/virtualHardDisks@2024-01-01"
  name      = each.key
  location  = var.location
  parent_id = var.resource_group_id

  # Disable schema validation for Azure Local resources
  schema_validation_enabled = false

  body = {
    extendedLocation = {
      type = "CustomLocation"
      name = var.custom_location_id
    }
    properties = {
      diskSizeGB = each.value.disk.size_gb
      dynamic    = true
    }
    tags = merge(local.common_tags, each.value.vm_tags, {
      VMName = each.value.vm_name
      LUN    = tostring(each.value.disk.lun)
    })
  }
}

# -----------------------------------------------------------------------------
# Virtual Machines - Azure Local VMs via azapi
# -----------------------------------------------------------------------------
# CONCEPT: Azure Local VMs (stack-hci-vm) are different from public Azure VMs:
# - They run on your Azure Local hardware
# - They're managed via Azure Arc
# - They use Custom Locations instead of Azure regions
# - They use Logical Networks instead of VNets
# - They use local gallery images
#
# The API schema differs from public Azure VMs - see Azure Verified Module:
# https://registry.terraform.io/modules/Azure/avm-res-azurestackhci-virtualmachineinstance

resource "azapi_resource" "vm" {
  for_each = local.vm_map

  # Using 2023-09-01-preview API which is well-documented in Azure Verified Modules
  type      = "Microsoft.AzureStackHCI/virtualMachineInstances@2023-09-01-preview"
  name      = "default" # Azure Local VMs use "default" as the instance name
  parent_id = azapi_resource.arc_machine[each.key].id

  # Disable schema validation for Azure Local resources
  schema_validation_enabled = false

  body = {
    extendedLocation = {
      type = "CustomLocation"
      name = var.custom_location_id
    }
    properties = {
      # Hardware profile - Azure Local uses different format than public Azure
      # vmSize must be "Custom" with explicit processors and memoryMB
      hardwareProfile = {
        vmSize     = "Custom"
        processors = local.vm_processors
        memoryMB   = local.vm_memory_mb
      }

      # OS profile - Authentication and customization
      osProfile = {
        computerName  = each.key
        adminUsername = coalesce(each.value.admin_username, var.admin_username)
        adminPassword = var.admin_password

        # Linux SSH configuration
        linuxConfiguration = var.os_type == "Linux" ? {
          ssh = var.ssh_public_key != null ? {
            publicKeys = [
              {
                path    = "/home/${coalesce(each.value.admin_username, var.admin_username)}/.ssh/authorized_keys"
                keyData = var.ssh_public_key
              }
            ]
          } : {}
        } : null

        # Windows configuration
        windowsConfiguration = var.os_type == "Windows" ? {
          provisionVMAgent       = true
          provisionVMConfigAgent = true
          ssh                    = {}
        } : null
      }

      # Storage profile - Simplified for Azure Local
      storageProfile = {
        imageReference = {
          id = var.gallery_image_id
        }
        osDisk = {
          osType = var.os_type
        }
        # Data disks as references to separately created disks
        dataDisks = [
          for key, disk in azapi_resource.data_disk : {
            id = disk.id
          } if startswith(key, each.key)
        ]
      }

      # Network profile - attach the NIC
      networkProfile = {
        networkInterfaces = [
          {
            id = azapi_resource.nic[each.key].id
          }
        ]
      }
    }
  }

  # Ensure NIC, data disks, and Arc machine are created first
  depends_on = [
    azapi_resource.nic,
    azapi_resource.data_disk,
    terraform_data.validate_linux_auth,
    terraform_data.validate_windows_auth,
    azapi_resource.arc_machine
  ]

  # Timeouts for VM operations - Azure Local VMs can take longer
  timeouts {
    create = "2h"
    update = "1h"
    delete = "30m"
  }
}

# -----------------------------------------------------------------------------
# Arc Machine Registration
# -----------------------------------------------------------------------------
# CONCEPT: Azure Local VMs are automatically Arc-enabled. The Azure Arc machine
# resource is created as part of the VM deployment process. This resource
# represents the VM in Azure for management purposes.

resource "azapi_resource" "arc_machine" {
  for_each = local.vm_map

  type      = "Microsoft.HybridCompute/machines@2024-03-31-preview"
  name      = each.key
  location  = var.location
  parent_id = var.resource_group_id

  # Disable schema validation for preview API
  schema_validation_enabled = false

  # The Arc machine is a prerequisite for the VM instance
  # It will be populated with details once the VM is created
  body = {
    kind = "HCI"
    identity = {
      type = "SystemAssigned"
    }
    tags = merge(local.common_tags, each.value.tags)
  }
}
