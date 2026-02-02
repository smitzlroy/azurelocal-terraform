# =============================================================================
# Azure Local VM Module - Provider Version Constraints
# =============================================================================
# This file pins the Terraform and provider versions required for this module.
# 
# IMPORTANT: This module uses both azurerm (for standard resources) and azapi
# (for Azure Local-specific resources that may not yet be fully supported in azurerm).
#
# For reference, see the AKS Arc Terraform documentation:
# https://learn.microsoft.com/en-us/azure/aks/aksarc/create-clusters-terraform
# =============================================================================

terraform {
  required_version = "~> 1.5"

  required_providers {
    # Azure Resource Manager provider - used for standard Azure resources
    # and Azure Local resources that have full azurerm support
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }

    # Azure API provider - used for Azure Local resources that require
    # direct ARM API access or are not yet fully supported in azurerm
    # This is essential for stack-hci-vm resources
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.0"
    }

    # Random provider for generating unique identifiers
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}
