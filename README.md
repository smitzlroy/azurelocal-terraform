# Azure Local Terraform Module

[![Terraform](https://img.shields.io/badge/Terraform-%3E%3D1.5-blue.svg)](https://www.terraform.io)
[![Azure Local](https://img.shields.io/badge/Azure%20Local-Supported-0078D4.svg)](https://learn.microsoft.com/en-us/azure/azure-local/)

Production-quality Terraform module for deploying Virtual Machines on [Azure Local](https://learn.microsoft.com/en-us/azure/azure-local/) (formerly Azure Stack HCI).

> **Familiar Developer Experience**: This module follows the same patterns as Microsoft's [AKS Arc Terraform documentation](https://learn.microsoft.com/en-us/azure/aks/aksarc/create-clusters-terraform), providing a consistent experience for users who already deploy resources to Azure Local via Terraform.

## Features

- ✅ **Linux & Windows VMs** with SSH key or password authentication
- ✅ **Azure Arc Enabled** - Automatic Arc agent installation for remote management
- ✅ **SSH via Azure Arc** - Connect to VMs without direct network access
- ✅ **Cloud-init Support** - Customise Linux VMs at first boot
- ✅ **Static IP or DHCP** - Flexible networking options
- ✅ **Data Disks** - Attach multiple data disks per VM
- ✅ **Guest Management** - Automatic guest agent and Arc Connected Machine agent

## Overview

This repository contains a Terraform module and examples for deploying VMs to Azure Local, enabling customers who already use Terraform in public Azure to create Azure Local resources with a similar developer experience.

### What is Azure Local?

Azure Local is Microsoft's hybrid cloud solution that runs Azure services on your on-premises hardware. Key components include:

- **Custom Location**: An Azure Arc-enabled location representing your Azure Local cluster
- **Logical Network**: Network connectivity for VMs (similar to VNet/Subnet in public Azure)
- **Arc Resource Bridge**: Enables Azure Arc integration with Azure Local
- **Gallery Images**: VM images stored locally on your Azure Local cluster

## Architecture: Azure Local VM Agents

Azure Local VMs require **two agents** for full Azure Arc functionality:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         AZURE LOCAL VM AGENTS                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  1. MOC GUEST AGENT (mocguestagent)                                         │
│     ├── PURPOSE: Communication bridge between Azure and the VM              │
│     ├── INSTALLATION: Via ISO mounted at VM creation                        │
│     ├── ENABLED BY: provisionVMConfigAgent = true                           │
│     └── REQUIRED FOR: Enabling guest management                             │
│                                                                             │
│  2. AZURE CONNECTED MACHINE AGENT (Arc Agent)                               │
│     ├── PURPOSE: Full Azure Arc capabilities                                │
│     ├── INSTALLATION: Installed BY mocguestagent when guest mgmt enabled    │
│     ├── ENABLED BY: az stack-hci-vm update --enable-agent true              │
│     └── ENABLES: SSH via Arc, VM extensions, Azure management               │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘

                          INSTALLATION FLOW
                          
  VM Creation ──► provisionVMConfigAgent=true ──► MOC Guest Agent starts
       │                                                   │
       │                                                   ▼
       │                                          Status: "Connected"
       │                                                   │
       │         enable_guest_management = true            │
       │         (automatic in this module)                ▼
       └──────────────────────────────────────────► Arc Agent Installed
                                                    SSH via Arc available!
```

This module **automatically handles both agents** - you don't need to do anything manually.

## Connecting to VMs

### Option 1: SSH via Azure Arc (Recommended)

No direct network access required - works from anywhere with Azure CLI:

```bash
# SSH using Azure Arc
az ssh vm --resource-group <resource-group> \
          --name <vm-name> \
          --local-user <username> \
          --private-key-file <path-to-private-key>

# Example
az ssh vm -g myResourceGroup -n myVM --local-user azureadmin --private-key-file ~/.ssh/id_rsa
```

### Option 2: Direct SSH (Requires Network Access)

If you have network connectivity to the Logical Network:

```bash
# Get the VM's IP address
az stack-hci-vm network nic show --name <vm-name>-nic \
  --resource-group <resource-group> \
  --query "properties.ipConfigurations[0].properties.privateIpAddress" -o tsv

# SSH directly
ssh -i <private-key> <username>@<ip-address>
```

## Quick Start

```bash
# 1. Sign in to Azure
az login

# 2. Navigate to an example
cd examples/single-linux-vm

# 3. Configure variables
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values

# 4. Initialize Terraform
terraform init -upgrade

# 5. Create execution plan
terraform plan -out main.tfplan

# 6. Apply
terraform apply main.tfplan
```

## Concept Mapping: Public Azure vs Azure Local

This table helps customers understand what changes when moving Terraform configurations from public Azure to Azure Local.

### Infrastructure & Location

| Public Azure | Azure Local | Notes |
|-------------|-------------|-------|
| Azure Region (e.g., `westeurope`) | Custom Location | Represents your on-prem Azure Local cluster |
| Availability Zone | Cluster Node | HA via cluster failover, not zones |
| Availability Set | N/A | Use cluster-level HA instead |
| Resource Group | Resource Group | Same concept, same resource |
| Subscription | Subscription | Same concept, cluster registered to subscription |

### Compute

| Public Azure | Azure Local | Notes |
|-------------|-------------|-------|
| `azurerm_virtual_machine` | `azapi_resource` (virtualMachineInstances) | Must use azapi provider |
| `azurerm_linux_virtual_machine` | `azapi_resource` + `os_type = "Linux"` | Unified resource, OS specified in properties |
| `azurerm_windows_virtual_machine` | `azapi_resource` + `os_type = "Windows"` | Unified resource, OS specified in properties |
| VM Size (e.g., `Standard_D4s_v3`) | `vmSize = "Custom"` + processors/memoryMB | Explicit vCPU and memory, not SKU names |
| Azure VM Agent | MOC Guest Agent + Arc Agent | Two agents required (see architecture above) |
| VM Extensions | Arc VM Extensions | Installed via Arc Connected Machine agent |
| Azure Compute Gallery | Azure Local Gallery Images | Images stored on cluster storage |
| Marketplace Image | Marketplace Gallery Image | Must be downloaded to cluster first |
| Custom Image (VHD) | Gallery Image from VHD | Upload VHD to cluster storage |
| VM Scale Sets | N/A | Use multiple VMs with Terraform count/for_each |
| Spot VMs | N/A | Not applicable to on-premises |
| Reserved Instances | N/A | You own the hardware |

### Networking

| Public Azure | Azure Local | Notes |
|-------------|-------------|-------|
| Virtual Network (VNet) | Logical Network | Maps to physical or SDN network |
| Subnet | Logical Network | Flat network model (no subnet hierarchy) |
| Network Interface (NIC) | Network Interface | Same concept, different API |
| Public IP | N/A (use Arc SSH) | No public IPs; use Azure Arc for remote access |
| Private IP (Dynamic) | DHCP from Logical Network | Logical Network must have DHCP scope |
| Private IP (Static) | Static IP from Logical Network | IP must be in Logical Network range |
| Network Security Group | NSG (Azure Local 2506+) | Supported on newer versions |
| Application Security Group | N/A | Not currently supported |
| Load Balancer | Software LB or physical LB | Use SDN Load Balancer or external |
| Azure Firewall | N/A | Use on-prem firewall appliances |
| VNet Peering | N/A | Networks are physical/SDN based |
| Private Endpoint | N/A | Services run on-premises |
| DNS Zone | On-prem DNS | Integrate with existing DNS infrastructure |
| Bastion | Azure Arc SSH | `az ssh vm` provides secure remote access |

### Storage

| Public Azure | Azure Local | Notes |
|-------------|-------------|-------|
| Managed Disk | Virtual Hard Disk | Stored on cluster storage (S2D/Storage Spaces) |
| OS Disk | OS Disk | Automatically created from image |
| Data Disk | Data Disk (`virtualHardDisks`) | Create separately, attach to VM |
| Ultra Disk | N/A | Use local NVMe/SSD for performance |
| Premium SSD | Cluster storage tier | Performance depends on cluster storage config |
| Standard SSD/HDD | Cluster storage tier | Tiered storage based on cluster config |
| Disk Encryption | BitLocker | Cluster-level encryption |
| Azure Files | SMB Shares | Use cluster file shares or Storage Spaces |
| Blob Storage | N/A | Use Azure Storage account or local storage |

### Identity & Access

| Public Azure | Azure Local | Notes |
|-------------|-------------|-------|
| Managed Identity | Managed Identity (System-assigned) | Arc VMs support system-assigned identity |
| User-Assigned Identity | Limited support | Check current Azure Local version |
| Azure AD Authentication | Azure AD via Arc | Arc-enabled servers support AAD |
| RBAC | RBAC | Same Azure RBAC model |
| Key Vault | Key Vault (via Arc) | Access via managed identity |

### Management & Monitoring

| Public Azure | Azure Local | Notes |
|-------------|-------------|-------|
| Azure Monitor | Azure Monitor (via Arc) | Arc agent sends metrics/logs to Azure |
| Log Analytics | Log Analytics | Same workspace, data via Arc agent |
| VM Insights | VM Insights | Requires Arc Connected Machine agent |
| Boot Diagnostics | Serial Console (limited) | Check Azure Local version for support |
| Auto-shutdown | N/A | Implement via automation/scheduled tasks |
| Backup (Azure Backup) | Azure Backup (MARS agent) | Or use on-prem backup solution |
| Site Recovery | Azure Site Recovery | Supported for DR scenarios |
| Update Management | Azure Update Manager | Supported via Arc |

### Terraform Provider & API

| Public Azure | Azure Local | Notes |
|-------------|-------------|-------|
| `azurerm` provider | `azapi` provider | azurerm doesn't support Azure Local VMs |
| `azurerm_resource_group` | `azurerm_resource_group` | Same - can use azurerm |
| ARM API | Azure Local API (`2023-09-01-preview`) | Different API namespace |
| `Microsoft.Compute/virtualMachines` | `Microsoft.AzureStackHCI/virtualMachineInstances` | Different resource provider |
| `Microsoft.Network/virtualNetworks` | `Microsoft.AzureStackHCI/logicalNetworks` | Different resource provider |
| `Microsoft.Network/networkInterfaces` | `Microsoft.AzureStackHCI/networkInterfaces` | Different resource provider |
| `Microsoft.Compute/disks` | `Microsoft.AzureStackHCI/virtualHardDisks` | Different resource provider |

### CLI Commands

| Public Azure | Azure Local | Notes |
|-------------|-------------|-------|
| `az vm create` | `az stack-hci-vm create` | Different CLI command group |
| `az vm list` | `az stack-hci-vm list` | Different CLI command group |
| `az vm show` | `az stack-hci-vm show` | Different CLI command group |
| `az network vnet create` | `az stack-hci-vm network lnet create` | Logical network commands |
| `az network nic create` | `az stack-hci-vm network nic create` | NIC commands |
| `az vm image list` | `az stack-hci-vm image list` | Gallery image commands |
| `az ssh vm` | `az ssh vm` | Same! Works via Arc for both |

### Key Migration Considerations

1. **Provider Change**: You must use `azapi` provider for Azure Local VMs (azurerm doesn't support them)
2. **No VM Sizes**: Use explicit `processors` and `memoryMB` instead of SKU names
3. **Image Preparation**: Images must be downloaded to the cluster before use
4. **Network Model**: Simpler flat network model vs Azure's VNet/Subnet hierarchy
5. **Remote Access**: Use Azure Arc SSH instead of public IPs or Bastion
6. **Two Agents**: VMs need both MOC Guest Agent and Arc Connected Machine agent
7. **Resource IDs**: Use full ARM resource IDs, not just names

## Prerequisites

### Software Requirements

1. **Terraform** ~> 1.5
   ```bash
   # Install via winget (Windows)
   winget install Hashicorp.Terraform
   
   # Verify installation
   terraform -v
   ```

2. **Azure CLI** (latest version)
   ```bash
   # Install or update
   winget install Microsoft.AzureCLI
   
   # Verify installation
   az --version
   ```

### Azure Local Requirements

Obtain the following from your Azure Local infrastructure administrator:

| Requirement | Description | How to Get |
|-------------|-------------|------------|
| Subscription ID | Azure subscription with Azure Local | `az account show --query id` |
| Resource Group ID | Full ARM ID of resource group | `az group show --name <name> --query id` |
| Custom Location ID | Azure Local cluster identifier | `az customlocation show --name <name> --resource-group <rg> --query id` |
| Logical Network ID | Network for VM connectivity | `az stack-hci-vm network lnet show --name <name> --resource-group <rg> --query id` |
| Gallery Image ID | VM image in Azure Local gallery | `az stack-hci-vm image list --resource-group <rg> --query "[].id"` |

### SSH Keys (for Linux VMs)

```bash
# Create SSH key pair
ssh-keygen -t rsa -b 4096 -f ~/.ssh/azurelocal_rsa

# Or use Azure CLI
az sshkey create --name "mySSHKey" --resource-group "<rg>"
```

## Module Features

### VM Deployment Options

- **Single VM**: Deploy one VM with `vm_count = 1`
- **Multiple Identical VMs**: Scale out with `vm_count = N`
- **Heterogeneous VMs**: Use `vm_instances` map for per-VM configuration

### Key Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `vm_name` | Base name for VMs | Required |
| `vm_count` | Number of identical VMs | `1` |
| `vm_processors` | vCPUs per VM | `2` |
| `vm_memory_mb` | Memory in MB | `8192` |
| `os_type` | `"Linux"` or `"Windows"` | Required |
| `admin_username` | Administrator username | Required |
| `ssh_public_key` | SSH public key (Linux) | Required for Linux |
| `admin_password` | Admin password (Windows) | Required for Windows |
| `enable_guest_management` | Install Arc agent | `true` |

### Supported Configurations

| Feature | Linux | Windows |
|---------|-------|---------|
| SSH Key Authentication | ✅ | ❌ |
| Password Authentication | ❌ | ✅ |
| Cloud-init | ✅ | ❌ |
| Custom Data | ✅ | ✅ |
| Static IP | ✅ | ✅ |
| DHCP | ✅ | ✅ |
| Data Disks | ✅ | ✅ |
| Premium SSD | ✅ | ✅ |
| NSG (2506+) | ✅ | ✅ |

### Example: Multiple VMs with Static IPs

```hcl
module "web_servers" {
  source = "./modules/azlocal-vm"

  resource_group_id   = var.resource_group_id
  custom_location_id  = var.custom_location_id
  logical_network_id  = var.logical_network_id
  location            = var.location

  vm_name  = "web"
  os_type  = "Linux"
  
  vm_instances = {
    "web-01" = { size = "Standard_D4s_v3", static_ip = "192.168.1.10" }
    "web-02" = { size = "Standard_D4s_v3", static_ip = "192.168.1.11" }
  }

  admin_username   = "azureadmin"
  ssh_public_key   = file("~/.ssh/id_rsa.pub")
  gallery_image_id = var.gallery_image_id
}
```

## Known Differences vs Public Azure

### Networking
- **No VNet/Subnet hierarchy**: Azure Local uses flat Logical Networks
- **No Public IPs**: VMs use private IPs; access via VPN or jump host
- **SDN Optional**: Logical Networks can map to physical or SDN networks

### Compute
- **Limited VM Sizes**: Subset of Azure sizes available per cluster
- **Arc-enabled by Default**: All VMs are automatically Azure Arc-connected

### Storage
- **Local Storage**: Disks stored on Azure Local cluster storage
- **Image Pre-requisite**: Images must be downloaded to cluster before use

## Make Targets

```bash
# Format Terraform files
make fmt

# Validate configuration
make validate

# Initialize Terraform
make init

# Create execution plan
make plan

# Apply configuration
make apply

# Destroy resources
make destroy

# Clean up local files
make clean
```

## Pre-commit Hooks

This repository includes pre-commit hooks for code quality:

```bash
# Install pre-commit
pip install pre-commit

# Install hooks
pre-commit install

# Run manually
pre-commit run --all-files
```

## Acceptance Tests

The module has been tested with the following scenarios:

### Test 1: Single Linux VM
```bash
cd examples/single-linux-vm
terraform init -upgrade
terraform plan -out main.tfplan
terraform apply main.tfplan
# ✅ Creates 1 Linux VM, NIC, Arc machine
# ✅ Outputs show IP and resource IDs
```

### Test 2: Multiple VMs with Static IPs
```hcl
# Set vm_instances with 2 VMs and static IPs
vm_instances = {
  "vm-01" = { static_ip = "192.168.1.10" }
  "vm-02" = { static_ip = "192.168.1.11" }
}
# ✅ Creates 2 VMs with specified IPs
```

## Troubleshooting

### Common Issues

| Issue | Solution |
|-------|----------|
| Custom Location not found | Verify ID and access permissions |
| Gallery Image not found | Ensure image is downloaded to cluster |
| VM creation timeout | Check Azure Local cluster health |
| Cannot connect to VM | Use SSH via Arc (see above) |
| Arc agent not connected | Check `az connectedmachine show` status |
| Guest agent not running | Verify VM has outbound internet access |

### Checking VM Status

```bash
# Check VM status
az stack-hci-vm show --name <vm-name> --resource-group <rg> \
  --query "{powerState: properties.status.powerState, provisioningState: properties.provisioningState}"

# Check guest agent status
az stack-hci-vm show --name <vm-name> --resource-group <rg> \
  --query "properties.instanceView.vmAgent"

# Check Arc agent status (should show "Connected")
az connectedmachine show --name <vm-name> --resource-group <rg> \
  --query "{status: status, agentVersion: agentVersion}"
```

### Getting Logs

```bash
# Check VM status
az stack-hci-vm show --name <vm-name> --resource-group <rg>

# Check Arc machine status
az connectedmachine show --name <vm-name> --resource-group <rg>

# Get deployment activity
az monitor activity-log list --resource-group <rg> --offset 1h
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run `make fmt` and `make validate`
5. Submit a pull request

## Resources

- [Azure Local Documentation](https://learn.microsoft.com/en-us/azure/azure-local/)
- [Azure Local VM Management](https://learn.microsoft.com/en-us/azure/azure-local/manage/azure-arc-vm-management-overview)
- [AKS Arc Terraform Guide](https://learn.microsoft.com/en-us/azure/aks/aksarc/create-clusters-terraform)
- [Terraform AzAPI Provider](https://registry.terraform.io/providers/Azure/azapi/latest/docs)
- [Terraform AzureRM Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)

## License

MIT License - See [LICENSE](LICENSE) for details.
