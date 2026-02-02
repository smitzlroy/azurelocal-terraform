# =============================================================================
# Azure Local Terraform Module - Makefile
# =============================================================================
# This Makefile provides common Terraform workflow commands for development
# and deployment of Azure Local VMs.
#
# Usage: make <target>
# =============================================================================

.PHONY: all init fmt validate plan apply destroy clean help

# Default example to use
EXAMPLE ?= single-linux-vm
EXAMPLE_DIR = examples/$(EXAMPLE)

# Terraform state file
PLAN_FILE = main.tfplan

# -----------------------------------------------------------------------------
# Default target
# -----------------------------------------------------------------------------

all: help

# -----------------------------------------------------------------------------
# Terraform Workflow
# -----------------------------------------------------------------------------

## Initialize Terraform (with upgrade)
init:
	@echo "==> Initializing Terraform..."
	cd $(EXAMPLE_DIR) && terraform init -upgrade

## Format all Terraform files
fmt:
	@echo "==> Formatting Terraform files..."
	terraform fmt -recursive .

## Validate Terraform configuration
validate: fmt
	@echo "==> Validating Terraform configuration..."
	cd $(EXAMPLE_DIR) && terraform validate

## Create Terraform execution plan
plan: validate
	@echo "==> Creating Terraform plan..."
	cd $(EXAMPLE_DIR) && terraform plan -out $(PLAN_FILE)

## Apply Terraform configuration
apply:
	@echo "==> Applying Terraform configuration..."
	cd $(EXAMPLE_DIR) && terraform apply $(PLAN_FILE)

## Apply with auto-approve (use with caution!)
apply-auto:
	@echo "==> Applying Terraform configuration (auto-approve)..."
	cd $(EXAMPLE_DIR) && terraform apply -auto-approve

## Destroy all resources
destroy:
	@echo "==> Destroying Terraform resources..."
	cd $(EXAMPLE_DIR) && terraform destroy

## Destroy with auto-approve (use with caution!)
destroy-auto:
	@echo "==> Destroying Terraform resources (auto-approve)..."
	cd $(EXAMPLE_DIR) && terraform destroy -auto-approve

# -----------------------------------------------------------------------------
# Module Development
# -----------------------------------------------------------------------------

## Validate the module directly
module-validate:
	@echo "==> Validating module..."
	cd modules/azlocal-vm && terraform init -backend=false
	cd modules/azlocal-vm && terraform validate

## Generate module documentation
docs:
	@echo "==> Generating documentation..."
	@if command -v terraform-docs >/dev/null 2>&1; then \
		terraform-docs markdown modules/azlocal-vm > modules/azlocal-vm/INPUTS.md; \
		echo "Documentation generated at modules/azlocal-vm/INPUTS.md"; \
	else \
		echo "terraform-docs not installed. Install with: go install github.com/terraform-docs/terraform-docs@latest"; \
	fi

# -----------------------------------------------------------------------------
# Cleanup
# -----------------------------------------------------------------------------

## Clean up local Terraform files
clean:
	@echo "==> Cleaning up..."
	find . -type d -name ".terraform" -exec rm -rf {} + 2>/dev/null || true
	find . -type f -name "*.tfplan" -delete 2>/dev/null || true
	find . -type f -name ".terraform.lock.hcl" -delete 2>/dev/null || true
	find . -type f -name "terraform.tfstate*" -delete 2>/dev/null || true
	@echo "Cleanup complete."

# -----------------------------------------------------------------------------
# Pre-commit
# -----------------------------------------------------------------------------

## Install pre-commit hooks
pre-commit-install:
	@echo "==> Installing pre-commit hooks..."
	@if command -v pre-commit >/dev/null 2>&1; then \
		pre-commit install; \
	else \
		echo "pre-commit not installed. Install with: pip install pre-commit"; \
	fi

## Run pre-commit on all files
pre-commit-run:
	@echo "==> Running pre-commit..."
	@if command -v pre-commit >/dev/null 2>&1; then \
		pre-commit run --all-files; \
	else \
		echo "pre-commit not installed. Install with: pip install pre-commit"; \
	fi

# -----------------------------------------------------------------------------
# Azure CLI Helpers
# -----------------------------------------------------------------------------

## Login to Azure
az-login:
	@echo "==> Logging in to Azure..."
	az login

## List Azure Local Custom Locations
az-list-custom-locations:
	@echo "==> Listing Custom Locations..."
	az customlocation list --output table

## List Azure Local Logical Networks
az-list-logical-networks:
	@read -p "Enter Resource Group: " rg; \
	az stack-hci-vm network lnet list --resource-group $$rg --output table

## List Azure Local Gallery Images
az-list-images:
	@read -p "Enter Resource Group: " rg; \
	az stack-hci-vm image list --resource-group $$rg --output table

## List Azure Local VMs
az-list-vms:
	@read -p "Enter Resource Group: " rg; \
	az stack-hci-vm list --resource-group $$rg --output table

# -----------------------------------------------------------------------------
# Help
# -----------------------------------------------------------------------------

## Show this help message
help:
	@echo ""
	@echo "Azure Local Terraform Module - Make Targets"
	@echo "============================================"
	@echo ""
	@echo "Usage: make <target> [EXAMPLE=<example-name>]"
	@echo ""
	@echo "Examples:"
	@echo "  make init                    # Initialize default example"
	@echo "  make plan                    # Create execution plan"
	@echo "  make apply                   # Apply the plan"
	@echo "  make EXAMPLE=single-linux-vm plan  # Specify example"
	@echo ""
	@echo "Terraform Workflow:"
	@echo "  init          Initialize Terraform (with upgrade)"
	@echo "  fmt           Format all Terraform files"
	@echo "  validate      Validate Terraform configuration"
	@echo "  plan          Create Terraform execution plan"
	@echo "  apply         Apply Terraform configuration"
	@echo "  apply-auto    Apply with auto-approve (caution!)"
	@echo "  destroy       Destroy all resources"
	@echo "  destroy-auto  Destroy with auto-approve (caution!)"
	@echo ""
	@echo "Module Development:"
	@echo "  module-validate  Validate the module directly"
	@echo "  docs             Generate module documentation"
	@echo ""
	@echo "Cleanup:"
	@echo "  clean         Clean up local Terraform files"
	@echo ""
	@echo "Pre-commit:"
	@echo "  pre-commit-install  Install pre-commit hooks"
	@echo "  pre-commit-run      Run pre-commit on all files"
	@echo ""
	@echo "Azure CLI Helpers:"
	@echo "  az-login                 Login to Azure"
	@echo "  az-list-custom-locations List Custom Locations"
	@echo "  az-list-logical-networks List Logical Networks"
	@echo "  az-list-images           List Gallery Images"
	@echo "  az-list-vms              List Azure Local VMs"
	@echo ""
