# Azure Local VM Terraform Module

This Terraform module creates virtual machines on [Azure Local](https://learn.microsoft.com/en-us/azure/azure-local/) (formerly Azure Stack HCI) using the `azurerm` and `azapi` providers.

> **Developer Experience**: This module follows the same patterns as Microsoft's [AKS Arc Terraform documentation](https://learn.microsoft.com/en-us/azure/aks/aksarc/create-clusters-terraform), making it familiar for users who already deploy Kubernetes clusters to Azure Local via Terraform.

## Quick Start

### Prerequisites

Before you begin, ensure you have:

1. **Terraform** installed (version ~> 1.5)
   ```bash
   terraform -v
   ```

2. **Azure CLI** installed and authenticated
   ```bash
   az login
   ```

3. **Required IDs** from your Azure Local infrastructure administrator:
   - **Subscription ID**: Azure subscription where Azure Local is registered
   - **Resource Group ID**: Full ARM ID of the resource group
   - **Custom Location ID**: ARM ID of the Azure Local Custom Location
   - **Logical Network ID**: ARM ID of the Logical Network for VM connectivity
   - **Gallery Image ID**: ARM ID of a VM image in the Azure Local gallery

4. **SSH Key Pair** (for Linux VMs):
   ```bash
   # Create SSH key pair
   ssh-keygen -t rsa -b 4096 -f ~/.ssh/azurelocal_rsa
   
   # Or create in Azure
   az sshkey create --name "mySSHKey" --resource-group "<resource-group>"
   ```

### Deploy Your First VM

```bash
# 1. Sign in to Azure
az login

# 2. Initialize Terraform
terraform init -upgrade

# 3. Create execution plan
terraform plan -out main.tfplan

# 4. Apply the configuration
terraform apply main.tfplan
```

## Concept Mapping: Public Azure vs Azure Local

| Public Azure Concept | Azure Local Equivalent | Notes |
|---------------------|----------------------|-------|
| Azure Region (e.g., `eastus`) | Custom Location | Represents your on-prem Azure Local cluster |
| Virtual Network (VNet) | Logical Network | Maps to physical/SDN network on Azure Local |
| Subnet | Logical Network | Azure Local uses flat networks; no subnet hierarchy |
| Azure VM Image | Gallery Image | Images stored locally on Azure Local cluster |
| Network Security Group | NSG (2506+) | Supported on Azure Local version 2506 and later |
| Public IP | Not Applicable | Azure Local VMs use private IPs on Logical Networks |
| Azure Bastion | Jump Host | Use a jump host or VPN for remote access |

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           Azure (Control Plane)                         │
│  ┌─────────────┐    ┌──────────────────┐    ┌─────────────────────┐    │
│  │  Resource   │    │ Custom Location  │    │   Arc Resource      │    │
│  │   Group     │◄───│  (Azure Local)   │◄───│     Bridge          │    │
│  └─────────────┘    └──────────────────┘    └─────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────┘
                                   │
                                   ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                    Azure Local Cluster (Data Plane)                     │
│  ┌─────────────┐    ┌──────────────────┐    ┌─────────────────────┐    │
│  │   VM(s)     │◄───│  Logical Network │◄───│   Gallery Images    │    │
│  │  + NICs     │    │  (Layer 2/SDN)   │    │   (Local Storage)   │    │
│  └─────────────┘    └──────────────────┘    └─────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────┘
```

## Known Differences vs Public Azure

### Networking
- **Logical Networks vs VNets**: Azure Local uses Logical Networks that map directly to physical network infrastructure or SDN (Software Defined Networking). There's no concept of subnets within a Logical Network.
- **IP Addressing**: VMs get IPs from the Logical Network's IP pool (static or DHCP). There are no public IPs—use VPN or jump hosts for remote access.
- **NSG Support**: Network Security Groups are supported on Azure Local version 2506 and later. They can be applied to NICs or Logical Networks.

### Compute
- **VM Sizes**: Azure Local supports a subset of Azure VM sizes. Check your cluster configuration for available sizes.
- **Arc-enabled by Default**: All Azure Local VMs are automatically Azure Arc-enabled, allowing Azure management features.

### Storage
- **Local Storage**: VM disks are stored on Azure Local cluster storage, not Azure regions.
- **Gallery Images**: Images must be downloaded/copied to your Azure Local cluster before use.

### Custom Location Requirement
- **Required for All Resources**: Unlike public Azure where you specify a region, Azure Local resources must specify a Custom Location ID that represents your Azure Local cluster.

## Usage Examples

### Basic Linux VM

```hcl
module "linux_vm" {
  source = "./modules/azlocal-vm"

  resource_group_id   = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mylocal-rg"
  custom_location_id  = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mylocal-rg/providers/Microsoft.ExtendedLocation/customLocations/mylocal-cl"
  logical_network_id  = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mylocal-rg/providers/Microsoft.AzureStackHCI/logicalNetworks/mylocal-lnet"
  location            = "eastus"

  vm_name         = "mylinuxvm"
  vm_size         = "Standard_D2s_v3"
  os_type         = "Linux"
  admin_username  = "azureadmin"
  ssh_public_key  = file("~/.ssh/id_rsa.pub")

  gallery_image_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mylocal-rg/providers/Microsoft.AzureStackHCI/galleryImages/ubuntu-22.04"

  tags = {
    Environment = "Development"
    Project     = "WebApp"
  }
}
```

### Multiple VMs with Static IPs

```hcl
module "web_servers" {
  source = "./modules/azlocal-vm"

  resource_group_id   = var.resource_group_id
  custom_location_id  = var.custom_location_id
  logical_network_id  = var.logical_network_id
  location            = var.location

  vm_name  = "web"
  os_type  = "Linux"
  
  # Use vm_instances for per-VM configuration
  vm_instances = {
    "web-server-01" = {
      size      = "Standard_D4s_v3"
      static_ip = "192.168.1.10"
    }
    "web-server-02" = {
      size      = "Standard_D4s_v3"
      static_ip = "192.168.1.11"
    }
  }

  admin_username   = "azureadmin"
  ssh_public_key   = file("~/.ssh/id_rsa.pub")
  gallery_image_id = var.gallery_image_id

  # Optional cloud-init for SSH hardening
  cloud_init = base64encode(file("cloud-init.yaml"))

  tags = {
    Environment = "Production"
    Tier        = "Web"
  }
}
```

### Windows VM

```hcl
module "windows_vm" {
  source = "./modules/azlocal-vm"

  resource_group_id   = var.resource_group_id
  custom_location_id  = var.custom_location_id
  logical_network_id  = var.logical_network_id
  location            = var.location

  vm_name         = "winvm"
  vm_size         = "Standard_D4s_v3"
  os_type         = "Windows"
  admin_username  = "azureadmin"
  admin_password  = var.admin_password  # Sensitive

  gallery_image_id = var.windows_image_id

  # Windows-specific options
  timezone      = "Pacific Standard Time"
  winrm_enable  = true

  # OS disk sizing
  os_disk_size_gb = 128
  os_disk_type    = "Premium_LRS"

  # Data disks
  data_disks = [
    {
      size_gb      = 256
      storage_type = "Premium_LRS"
      caching      = "ReadOnly"
      lun          = 0
    }
  ]

  tags = {
    Environment = "Production"
    OS          = "Windows"
  }
}
```

## Input Variables

| Name | Description | Type | Required | Default |
|------|-------------|------|----------|---------|
| `resource_group_id` | Full ARM ID of the resource group | `string` | Yes | - |
| `custom_location_id` | ARM ID of the Azure Local Custom Location | `string` | Yes | - |
| `logical_network_id` | ARM ID of the Logical Network | `string` | Yes | - |
| `location` | Azure region where Azure Local is registered | `string` | Yes | - |
| `vm_name` | Base name for VMs | `string` | Yes | - |
| `vm_count` | Number of identical VMs (ignored if `vm_instances` is set) | `number` | No | `1` |
| `vm_instances` | Map of VM names with per-VM overrides | `map(object)` | No | `{}` |
| `vm_size` | Default VM size | `string` | No | `Standard_D2s_v3` |
| `os_type` | Operating system type (`Linux` or `Windows`) | `string` | Yes | - |
| `admin_username` | Administrator username | `string` | No | `azureadmin` |
| `ssh_public_key` | SSH public key for Linux VMs | `string` | Conditional | - |
| `admin_password` | Password for Windows VMs | `string` | Conditional | - |
| `gallery_image_id` | ARM ID of Azure Local gallery image | `string` | Conditional | - |
| `image_reference` | Marketplace image reference | `object` | Conditional | - |
| `static_ip` | Default static IP (for single VM) | `string` | No | `null` |
| `dns_servers` | DNS server IP addresses | `list(string)` | No | `[]` |
| `nsg_id` | NSG ID to attach (Azure Local 2506+) | `string` | No | `null` |
| `cloud_init` | Base64-encoded cloud-init for Linux | `string` | No | `null` |
| `custom_data` | Base64-encoded custom data for Windows | `string` | No | `null` |
| `timezone` | Windows timezone | `string` | No | `UTC` |
| `winrm_enable` | Enable WinRM for Windows | `bool` | No | `false` |
| `os_disk_size_gb` | OS disk size in GB | `number` | No | Image default |
| `os_disk_type` | OS disk storage type | `string` | No | `Premium_LRS` |
| `data_disks` | List of data disk configurations | `list(object)` | No | `[]` |
| `tags` | Tags to apply to all resources | `map(string)` | No | `{}` |

## Outputs

| Name | Description |
|------|-------------|
| `vm_ids` | Map of VM names to ARM resource IDs |
| `vm_names` | List of created VM names |
| `arc_machine_ids` | Map of VM names to Arc Machine IDs |
| `nic_ids` | Map of VM names to NIC resource IDs |
| `private_ips` | Map of VM names to private IP addresses |
| `static_ips` | Map of VMs with static IPs only |
| `data_disk_ids` | Map of data disk keys to resource IDs |
| `ssh_connection_commands` | SSH commands for Linux VMs |
| `rdp_connection_info` | RDP connection info for Windows VMs |
| `deployment_summary` | Summary of the deployment |

## Validation Steps

After deployment, validate your VMs:

```bash
# List VMs in the resource group
az stack-hci-vm list --resource-group mylocal-rg --output table

# Show VM details
az stack-hci-vm show --name mylinuxvm-001 --resource-group mylocal-rg

# Check Arc machine status
az connectedmachine show --name mylinuxvm-001 --resource-group mylocal-rg

# SSH to Linux VM (requires network connectivity)
ssh azureadmin@<VM_IP>
```

## Troubleshooting

### Common Issues

1. **"Custom Location not found"**: Ensure the Custom Location ID is correct and you have access to it.

2. **"Logical Network not found"**: Verify the Logical Network exists and the ID is correct.

3. **"Gallery Image not found"**: Ensure the image is downloaded to your Azure Local cluster.

4. **"VM creation timeout"**: Azure Local VMs may take longer to provision than public Azure VMs. Check the Azure Local cluster health.

5. **"Cannot connect to VM"**: Ensure you have network connectivity to the Logical Network (VPN, jump host, or direct access).

### Getting Help

- [Azure Local Documentation](https://learn.microsoft.com/en-us/azure/azure-local/)
- [Azure Local VM Management](https://learn.microsoft.com/en-us/azure/azure-local/manage/azure-arc-vm-management-overview)
- [Terraform AzAPI Provider](https://registry.terraform.io/providers/Azure/azapi/latest/docs)

## License

MIT License - See [LICENSE](../../LICENSE) for details.
