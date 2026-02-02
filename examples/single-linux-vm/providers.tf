# =============================================================================
# Azure Local VM Example - Provider Configuration
# =============================================================================
# This example demonstrates deploying a single Linux VM to Azure Local using
# the azlocal-vm module. The configuration follows the same patterns as
# Microsoft's AKS Arc Terraform documentation.
#
# AUTHENTICATION: This example uses Azure CLI authentication (az login).
# This is the recommended approach, matching the AKS Arc Terraform workflow.
#
# For reference: https://learn.microsoft.com/en-us/azure/aks/aksarc/create-clusters-terraform
# =============================================================================

terraform {
  required_version = "~> 1.5"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }

    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

# -----------------------------------------------------------------------------
# Azure Resource Manager Provider
# -----------------------------------------------------------------------------
# Configuration follows AKS Arc Terraform documentation patterns.
# Uses subscription_id variable for explicit subscription targeting.

provider "azurerm" {
  features {
    resource_group {
      # Set to false to allow destroying resource groups with resources
      # This matches the AKS Arc Terraform example configuration
      prevent_deletion_if_contains_resources = false
    }
  }

  subscription_id = var.subscription_id
}

# -----------------------------------------------------------------------------
# Azure API Provider
# -----------------------------------------------------------------------------
# The azapi provider is used for Azure Local (stack-hci-vm) resources that
# may not be fully supported in the azurerm provider yet.

provider "azapi" {
  subscription_id = var.subscription_id
}

# -----------------------------------------------------------------------------
# Random Provider
# -----------------------------------------------------------------------------
# Used for generating unique identifiers when needed

provider "random" {}
