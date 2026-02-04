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

## Migrating Terraform from Public Azure to Azure Local

This section helps you understand what changes in your Terraform code when moving from public Azure to Azure Local.

### 🔴 Must Change in Your Terraform Code

These require code changes - you cannot use the same Terraform resources:

| What | Public Azure | Azure Local | Example Change |
|------|-------------|-------------|----------------|
| **Provider** | `azurerm` | `azapi` | Add `azapi` provider for VM resources |
| **VM Resource** | `azurerm_linux_virtual_machine` | `azapi_resource` | Complete resource rewrite required |
| **VM Size** | `size = "Standard_D4s_v3"` | `vmSize = "Custom"` + `processors` + `memoryMB` | `processors = 4, memoryMB = 16384` |
| **Location** | `location = "westeurope"` | `extendedLocation` block with Custom Location ID | See example below |
| **NIC Resource** | `azurerm_network_interface` | `azapi_resource` (networkInterfaces) | Different API, different properties |
| **Network** | `subnet_id` | `logical_network_id` | Reference Logical Network instead of Subnet |
| **Image** | `source_image_reference {}` | `imageReference.id` | Use Gallery Image ID |
| **Data Disk** | `azurerm_managed_disk` | `azapi_resource` (virtualHardDisks) | Different resource type |

**Example - Location change:**
```hcl
# Public Azure
resource "azurerm_linux_virtual_machine" "vm" {
  location = "westeurope"
}

# Azure Local
resource "azapi_resource" "vm" {
  body = {
    extendedLocation = {
      type = "CustomLocation"
      name = "/subscriptions/.../customLocations/my-cluster"
    }
  }
}
```

### 🟢 No Changes Required

These work exactly the same way:

| What | Notes |
|------|-------|
| `azurerm_resource_group` | Same resource, same provider |
| `azurerm` provider for non-VM resources | Keep for resource groups, RBAC, etc. |
| Resource Group references | Same concept |
| Subscription references | Same concept |
| Tags | Same syntax, same behavior |
| RBAC / Role Assignments | Same Azure RBAC model |
| Terraform state management | Same backend options |
| Variables & Outputs | Same Terraform syntax |

### 🟡 Conceptual Differences (No Code, But Important to Know)

These don't require code changes but affect how you think about your infrastructure:

| Concept | Public Azure | Azure Local | Why It Matters |
|---------|-------------|-------------|----------------|
| **Where VMs run** | Microsoft datacenters | Your on-prem hardware | You manage the hardware |
| **High Availability** | Availability Zones/Sets | Cluster failover | HA is automatic at cluster level |
| **Network model** | VNet → Subnet → NIC | Logical Network → NIC | Simpler, flat network model |
| **VM Agent** | Single Azure VM Agent | Two agents (MOC + Arc) | Module handles this automatically |
| **Remote access** | Public IP / Bastion | Azure Arc SSH | `az ssh vm` works from anywhere |
| **Image source** | Azure Marketplace (instant) | Must download to cluster first | Pre-download images |
| **Scaling** | VM Scale Sets | Terraform `count`/`for_each` | No native scale sets |
| **Public IPs** | Available | Not applicable | Use Arc SSH instead |

### 🔵 Not Available on Azure Local

Remove these from your Terraform code - they don't apply:

| Feature | Alternative |
|---------|-------------|
| VM Scale Sets | Use `count` or `for_each` in Terraform |
| Spot/Spot VMs | N/A (you own the hardware) |
| Reserved Instances | N/A (you own the hardware) |
| Public IP addresses | Use Azure Arc SSH for remote access |
| Azure Bastion | Use Azure Arc SSH |
| Azure Firewall | Use on-prem firewall |
| VNet Peering | Physical/SDN network design |
| Application Security Groups | NSGs only (Azure Local 2506+) |
| Ultra Disks | Use local NVMe/SSD |

### Quick Reference: API Changes

| Resource | Public Azure API | Azure Local API |
|----------|-----------------|-----------------|
| VM | `Microsoft.Compute/virtualMachines` | `Microsoft.AzureStackHCI/virtualMachineInstances` |
| NIC | `Microsoft.Network/networkInterfaces` | `Microsoft.AzureStackHCI/networkInterfaces` |
| Disk | `Microsoft.Compute/disks` | `Microsoft.AzureStackHCI/virtualHardDisks` |
| Network | `Microsoft.Network/virtualNetworks` | `Microsoft.AzureStackHCI/logicalNetworks` |
| Image | `Microsoft.Compute/galleries` | `Microsoft.AzureStackHCI/galleryImages` |

### Quick Reference: CLI Commands

| Task | Public Azure | Azure Local |
|------|-------------|-------------|
| Create VM | `az vm create` | `az stack-hci-vm create` |
| List VMs | `az vm list` | `az stack-hci-vm list` |
| SSH to VM | `az ssh vm` | `az ssh vm` ✅ Same! |
| List images | `az vm image list` | `az stack-hci-vm image list` |

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
