# Azure Local Terraform Module

[![Terraform](https://img.shields.io/badge/Terraform-%3E%3D1.5-blue.svg)](https://www.terraform.io)
[![Azure Local](https://img.shields.io/badge/Azure%20Local-Supported-0078D4.svg)](https://learn.microsoft.com/en-us/azure/azure-local/)

Production-quality Terraform module for deploying Virtual Machines on [Azure Local](https://learn.microsoft.com/en-us/azure/azure-local/) (formerly Azure Stack HCI).

> **Familiar Developer Experience**: This module follows the same patterns as Microsoft's [AKS Arc Terraform documentation](https://learn.microsoft.com/en-us/azure/aks/aksarc/create-clusters-terraform), providing a consistent experience for users who already deploy resources to Azure Local via Terraform.

## Overview

This repository contains a Terraform module and examples for deploying VMs to Azure Local, enabling customers who already use Terraform in public Azure to create Azure Local resources with a similar developer experience.

### What is Azure Local?

Azure Local is Microsoft's hybrid cloud solution that runs Azure services on your on-premises hardware. Key components include:

- **Custom Location**: An Azure Arc-enabled location representing your Azure Local cluster
- **Logical Network**: Network connectivity for VMs (similar to VNet/Subnet in public Azure)
- **Arc Resource Bridge**: Enables Azure Arc integration with Azure Local
- **Gallery Images**: VM images stored locally on your Azure Local cluster

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

## Repository Structure

```
.
├── modules/
│   └── azlocal-vm/           # Main VM module
│       ├── main.tf           # Resource definitions
│       ├── variables.tf      # Input variables
│       ├── outputs.tf        # Output values
│       ├── versions.tf       # Provider constraints
│       └── README.md         # Module documentation
├── examples/
│   └── single-linux-vm/      # Single Linux VM example
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       ├── providers.tf
│       ├── terraform.tfvars.example
│       └── README.md
├── Makefile                  # Build automation
├── .pre-commit-config.yaml   # Pre-commit hooks
├── .gitignore
└── README.md                 # This file
```

## Concept Mapping: Public Azure vs Azure Local

| Public Azure | Azure Local | Notes |
|-------------|-------------|-------|
| Azure Region | Custom Location | Represents your on-prem cluster |
| Virtual Network | Logical Network | Maps to physical/SDN network |
| Subnet | Logical Network | Flat networks (no subnet hierarchy) |
| Azure VM Image | Gallery Image | Images stored locally |
| `azurerm_virtual_machine` | `azapi_resource` (stack-hci-vm) | Different resource type |
| Network Security Group | NSG (2506+) | Supported on Azure Local 2506+ |

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
| Cannot connect to VM | Verify network connectivity to Logical Network |

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
