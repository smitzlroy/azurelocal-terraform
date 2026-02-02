# =============================================================================
# Azure Local VM Example - Main Configuration
# =============================================================================
# This example creates a single Linux VM on Azure Local with:
# - SSH key authentication
# - Cloud-init for initial configuration and SSH hardening
# - Optional static IP assignment
#
# The configuration follows Microsoft's AKS Arc Terraform patterns for
# a consistent developer experience across Azure Local workloads.
# =============================================================================

# -----------------------------------------------------------------------------
# Cloud-Init Configuration for SSH Hardening
# -----------------------------------------------------------------------------
# This cloud-init configuration:
# - Disables password authentication
# - Configures SSH key-only access
# - Installs basic security packages
# - Sets up automatic security updates

locals {
  cloud_init_content = <<-CLOUDINIT
    #cloud-config
    # ==========================================================================
    # Cloud-init configuration for Azure Local Linux VM
    # This configuration hardens SSH and sets up basic security
    # ==========================================================================

    # Update package lists and upgrade existing packages
    package_update: true
    package_upgrade: true

    # Install essential packages
    packages:
      - curl
      - wget
      - vim
      - htop
      - unattended-upgrades
      - fail2ban

    # SSH configuration - security hardening
    ssh_pwauth: false
    disable_root: true

    # Configure SSH daemon
    write_files:
      - path: /etc/ssh/sshd_config.d/99-azure-local-hardening.conf
        content: |
          # Azure Local SSH Hardening Configuration
          PasswordAuthentication no
          PubkeyAuthentication yes
          PermitRootLogin no
          MaxAuthTries 3
          ClientAliveInterval 300
          ClientAliveCountMax 2
          X11Forwarding no
          AllowAgentForwarding no
          AllowTcpForwarding no
        permissions: '0644'
        owner: root:root

      - path: /etc/fail2ban/jail.local
        content: |
          [sshd]
          enabled = true
          port = ssh
          filter = sshd
          logpath = /var/log/auth.log
          maxretry = 3
          bantime = 3600
        permissions: '0644'
        owner: root:root

    # Run commands after cloud-init
    runcmd:
      # Restart SSH to apply configuration
      - systemctl restart sshd
      # Enable and start fail2ban
      - systemctl enable fail2ban
      - systemctl start fail2ban
      # Enable automatic security updates
      - systemctl enable unattended-upgrades
      # Log completion
      - echo "Azure Local VM cloud-init configuration completed" | tee /var/log/cloud-init-complete.log

    # Final message
    final_message: "Azure Local Linux VM is ready after $UPTIME seconds"
  CLOUDINIT
}

# -----------------------------------------------------------------------------
# Azure Local VM Module
# -----------------------------------------------------------------------------

module "linux_vm" {
  source = "../../modules/azlocal-vm"

  # Required Azure Local infrastructure IDs
  # These are obtained from your Azure Local administrator
  resource_group_id  = var.resource_group_id
  custom_location_id = var.custom_location_id
  logical_network_id = var.logical_network_id
  location           = var.location

  # VM configuration
  vm_name       = var.vm_name
  vm_size       = var.vm_size
  vm_processors = var.vm_processors
  vm_memory_mb  = var.vm_memory_mb
  vm_count      = 1
  os_type       = "Linux"

  # Authentication - SSH key (required for Linux)
  admin_username = var.admin_username
  ssh_public_key = var.ssh_public_key

  # Image - Azure Local gallery image
  gallery_image_id = var.gallery_image_id

  # Network configuration
  static_ip   = var.static_ip
  dns_servers = var.dns_servers

  # Cloud-init for SSH hardening and initial setup
  cloud_init = base64encode(local.cloud_init_content)

  # Disk configuration (using defaults)
  os_disk_type = "Premium_LRS"

  # Tags
  tags = var.tags
}
