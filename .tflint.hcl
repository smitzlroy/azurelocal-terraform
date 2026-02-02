# =============================================================================
# TFLint Configuration
# =============================================================================
# Configuration for TFLint - Terraform linter
# https://github.com/terraform-linters/tflint
# =============================================================================

config {
  # Enable module inspection
  module = true

  # Disable specific checks as needed
  force = false
}

# -----------------------------------------------------------------------------
# Azure Plugin
# -----------------------------------------------------------------------------
plugin "azurerm" {
  enabled = true
  version = "0.25.1"
  source  = "github.com/terraform-linters/tflint-ruleset-azurerm"
}

# -----------------------------------------------------------------------------
# Terraform Rules
# -----------------------------------------------------------------------------

# Disallow deprecated (0.11-style) interpolation
rule "terraform_deprecated_interpolation" {
  enabled = true
}

# Disallow legacy dot index syntax
rule "terraform_deprecated_index" {
  enabled = true
}

# Disallow unused declarations
rule "terraform_unused_declarations" {
  enabled = true
}

# Disallow terraform.workspace
rule "terraform_workspace_remote" {
  enabled = true
}

# Ensure all modules have version constraints
rule "terraform_module_version" {
  enabled = true
}

# Ensure all resources have a comment
rule "terraform_comment_syntax" {
  enabled = true
}

# Naming conventions
rule "terraform_naming_convention" {
  enabled = true

  variable {
    format = "snake_case"
  }

  output {
    format = "snake_case"
  }

  resource {
    format = "snake_case"
  }

  data {
    format = "snake_case"
  }

  locals {
    format = "snake_case"
  }

  module {
    format = "snake_case"
  }
}

# Standard module structure
rule "terraform_standard_module_structure" {
  enabled = true
}

# Required version constraint
rule "terraform_required_version" {
  enabled = true
}

# Required providers
rule "terraform_required_providers" {
  enabled = true
}

# Typed variables
rule "terraform_typed_variables" {
  enabled = true
}
