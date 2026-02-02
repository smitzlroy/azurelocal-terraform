# Azure Local Single Linux VM Example

This example demonstrates how to deploy a single Linux VM to Azure Local using Terraform, following the same workflow patterns as [Microsoft's AKS Arc Terraform documentation](https://learn.microsoft.com/en-us/azure/aks/aksarc/create-clusters-terraform).

## Prerequisites

Before you begin, make sure you have:

1. **Terraform** installed (~> 1.5)
   ```bash
   terraform -v
   ```

2. **Azure CLI** installed and updated
   ```bash
   az --version
   ```

3. **SSH Key Pair** for Linux VM authentication
   ```bash
   # Create a new SSH key pair
   ssh-keygen -t rsa -b 4096 -f ~/.ssh/azurelocal_rsa
   
   # Or create using Azure CLI (stores in Azure)
   az sshkey create --name "mySSHKey" --resource-group "<resource-group>"
   ```

4. **Required Information** from your Azure Local administrator:
   - Subscription ID
   - Resource Group ID (full ARM ID)
   - Custom Location ID
   - Logical Network ID
   - Gallery Image ID (Linux image)

## Quick Start

### Step 1: Sign in to Azure

```bash
az login
```

If you have multiple subscriptions, set the correct one:
```bash
az account set --subscription "<subscription-id>"
```

### Step 2: Configure Variables

1. Copy the example variables file:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

2. Edit `terraform.tfvars` with your values:
   ```bash
   # Use your preferred editor
   code terraform.tfvars
   ```

### Step 3: Initialize Terraform

```bash
terraform init -upgrade
```

### Step 4: Review the Execution Plan

```bash
terraform plan -out main.tfplan
```

Review the plan to ensure it will create the expected resources.

### Step 5: Apply the Configuration

```bash
terraform apply main.tfplan
```

## Validate the Deployment

After the deployment completes, validate your VM:

```bash
# Check VM status
az stack-hci-vm show \
  --name "mylinuxvm-001" \
  --resource-group "<resource-group-name>"

# Check Arc machine status
az connectedmachine show \
  --name "mylinuxvm-001" \
  --resource-group "<resource-group-name>"

# Get NIC details (including IP address)
az stack-hci-vm nic show \
  --name "mylinuxvm-001-nic" \
  --resource-group "<resource-group-name>" \
  --query "properties.ipConfigurations"
```

## Connect to the VM

**Prerequisites**: You need network connectivity to the Azure Local Logical Network. This typically requires:
- VPN connection to your on-premises network
- Jump host/bastion in the same network
- Direct network access from your machine

```bash
# SSH to the VM
ssh -i ~/.ssh/azurelocal_rsa azureadmin@<VM_IP_ADDRESS>

# Verify cloud-init completed successfully
cat /var/log/cloud-init-complete.log

# Check fail2ban status (part of SSH hardening)
sudo systemctl status fail2ban
```

## Clean Up

To destroy all resources created by this example:

```bash
terraform destroy
```

## What's Deployed

This example creates:

| Resource | Description |
|----------|-------------|
| Azure Arc Machine | Arc representation of the VM for Azure management |
| Azure Local VM | Linux VM running on your Azure Local cluster |
| Network Interface | NIC attached to the Logical Network |

### Cloud-Init Configuration

The VM is configured with cloud-init that:
- Updates all packages
- Installs security tools (fail2ban, unattended-upgrades)
- Hardens SSH configuration (disables password auth, root login)
- Enables automatic security updates

## Customization

### Using a Static IP

Edit `terraform.tfvars`:
```hcl
static_ip = "192.168.1.10"
```

### Custom DNS Servers

Edit `terraform.tfvars`:
```hcl
dns_servers = ["10.0.0.5", "10.0.0.6"]
```

### Different VM Size

Edit `terraform.tfvars`:
```hcl
vm_size = "Standard_D4s_v3"
```

## Troubleshooting

### "Custom Location not found"
Verify the Custom Location ID and ensure you have access:
```bash
az customlocation show --ids "<custom-location-id>"
```

### "Gallery Image not found"
List available images:
```bash
az stack-hci-vm image list --resource-group "<rg>" --output table
```

### "Cannot connect to VM"
1. Verify the VM is running
2. Check you have network connectivity to the Logical Network
3. Ensure your SSH key matches

### Deployment Timeout
Azure Local VMs may take longer to provision. Check cluster health:
```bash
az stack-hci show --name "<cluster-name>" --resource-group "<rg>"
```

## Next Steps

- Try the [multiple VMs example](../multiple-linux-vms/) for scale-out scenarios
- Add [data disks](../../modules/azlocal-vm/README.md#data-disks) for additional storage
- Configure [monitoring with Azure Arc](https://learn.microsoft.com/en-us/azure/azure-arc/servers/concept-log-analytics-extension-deployment)
