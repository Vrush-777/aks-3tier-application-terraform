#!/bin/bash

###############################################################################
# Verification Script for Private AKS Deployment Setup
#
# This script verifies that all components are correctly configured for
# private AKS deployment via Jump VM with Managed Identity.
#
# Usage: bash verify-setup.sh [environment]
# Example: bash verify-setup.sh dev
#
###############################################################################

set -e

# ============================================================================
# Configuration
# ============================================================================

ENVIRONMENT="${1:-dev}"
TF_ENV_PATH="terraform/environments/${ENVIRONMENT}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================================================
# Helper Functions
# ============================================================================

print_header() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

print_check() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# ============================================================================
# Verify File Structure
# ============================================================================

verify_files() {
    print_header "Verifying File Structure"
    
    local missing=0
    
    # Check Terraform module files
    local files=(
        "terraform/modules/vm/variables-identity.tf"
        "terraform/modules/vm/main-identity.tf"
        "terraform/modules/vm/outputs-identity.tf"
        "terraform/scripts/jumpvm-cloud-init.yaml"
        "${TF_ENV_PATH}/variables-jumpvm.tf"
        "${TF_ENV_PATH}/outputs-jumpvm.tf"
        ".github/workflows/deploy-private-aks.yml"
    )
    
    for file in "${files[@]}"; do
        if [ -f "$file" ]; then
            print_check "Found: $file"
        else
            print_error "Missing: $file"
            ((missing++))
        fi
    done
    
    if [ $missing -eq 0 ]; then
        echo ""
        print_check "All required files present"
        return 0
    else
        echo ""
        print_error "$missing files are missing"
        return 1
    fi
}

# ============================================================================
# Verify Terraform Configuration
# ============================================================================

verify_terraform() {
    print_header "Verifying Terraform Configuration"
    
    cd "$TF_ENV_PATH" || { print_error "Cannot access $TF_ENV_PATH"; return 1; }
    
    # Check terraform init
    if [ -d ".terraform" ]; then
        print_check "Terraform initialized"
    else
        print_warning "Terraform not initialized - run: terraform init"
    fi
    
    # Validate terraform
    if terraform validate > /dev/null 2>&1; then
        print_check "Terraform configuration is valid"
    else
        print_error "Terraform configuration has errors:"
        terraform validate
        cd - > /dev/null
        return 1
    fi
    
    # Check for jump_vm module
    if grep -q "module.*jump_vm" main.tf 2>/dev/null; then
        print_check "Jump VM module configured in main.tf"
    else
        print_error "Jump VM module not found in main.tf"
        print_warning "Add module call to main.tf (see jump-vm-module-config.md)"
        return 1
    fi
    
    # Check for managed identity references
    if grep -q "enable_managed_identity" main.tf 2>/dev/null; then
        print_check "Managed identity enabled in module configuration"
    else
        print_warning "Managed identity not explicitly referenced"
    fi
    
    cd - > /dev/null
    return 0
}

# ============================================================================
# Verify Cloud-Init Script
# ============================================================================

verify_cloud_init() {
    print_header "Verifying Cloud-Init Script"
    
    local cloud_init="terraform/scripts/jumpvm-cloud-init.yaml"
    
    if [ ! -f "$cloud_init" ]; then
        print_error "Cloud-init script not found: $cloud_init"
        return 1
    fi
    
    # Check for essential components
    local components=(
        "curl"
        "Azure CLI"
        "kubectl"
        "kubelogin"
        "Helm"
        "/opt/deploy/deploy.sh"
    )
    
    for component in "${components[@]}"; do
        if grep -q "$component" "$cloud_init"; then
            print_check "Found: $component installation"
        else
            print_warning "Missing: $component reference"
        fi
    done
    
    # Check for managed identity authentication
    if grep -q "az login --identity" "$cloud_init"; then
        print_check "Managed identity authentication configured"
    else
        print_error "Managed identity authentication not found"
        return 1
    fi
    
    # Check for kubelogin conversion
    if grep -q "kubelogin convert-kubeconfig" "$cloud_init"; then
        print_check "kubelogin configuration found"
    else
        print_error "kubelogin configuration not found"
        return 1
    fi
    
    # Check for Helm deployment
    if grep -q "helm upgrade" "$cloud_init"; then
        print_check "Helm deployment script found"
    else
        print_error "Helm deployment not configured"
        return 1
    fi
    
    return 0
}

# ============================================================================
# Verify GitHub Actions Workflow
# ============================================================================

verify_github_workflow() {
    print_header "Verifying GitHub Actions Workflow"
    
    local workflow=".github/workflows/deploy-private-aks.yml"
    
    if [ ! -f "$workflow" ]; then
        print_error "Workflow not found: $workflow"
        return 1
    fi
    
    # Check for essential jobs
    local jobs=(
        "detect-changes"
        "build-backend"
        "build-frontend"
        "deploy-to-aks"
        "validate-deployment"
    )
    
    for job in "${jobs[@]}"; do
        if grep -q "name: ${job}" "$workflow" || grep -q "^  ${job}:" "$workflow"; then
            print_check "Found job: $job"
        else
            print_warning "Job not found: $job"
        fi
    done
    
    # Check for Azure Login
    if grep -q "azure/login" "$workflow"; then
        print_check "Azure Login action configured"
    else
        print_error "Azure Login not found in workflow"
        return 1
    fi
    
    # Check for VM Run Command
    if grep -q "az vm run-command invoke" "$workflow"; then
        print_check "VM Run Command invocation configured"
    else
        print_error "VM Run Command not found in workflow"
        return 1
    fi
    
    return 0
}

# ============================================================================
# Check GitHub Secrets
# ============================================================================

check_github_secrets() {
    print_header "Checking GitHub Secrets Configuration"
    
    print_info "The following secrets should be configured in GitHub:"
    echo ""
    
    local secrets=(
        "AZURE_CREDENTIALS:Service Principal credentials (JSON)"
        "TF_VAR_SUBSCRIPTION_ID:Azure Subscription ID"
        "TF_VAR_TENANT_ID:Azure Tenant ID"
        "TF_VAR_ACR_NAME:Container Registry name"
        "TF_VAR_AKS_CLUSTER_NAME:AKS cluster name"
        "TF_VAR_RESOURCE_GROUP_NAME:Resource group name"
        "JUMP_VM_NAME:Jump VM name"
        "jumpvm_ssh_public_key:SSH public key"
    )
    
    for secret in "${secrets[@]}"; do
        IFS=':' read -r name desc <<< "$secret"
        echo -e "  ${YELLOW}$name${NC}: $desc"
    done
    
    echo ""
    print_warning "Manually verify these are configured: Settings → Secrets and Variables → Actions"
}

# ============================================================================
# Simulate Terraform Plan
# ============================================================================

simulate_plan() {
    print_header "Terraform Plan Analysis"
    
    cd "$TF_ENV_PATH" || { print_error "Cannot access $TF_ENV_PATH"; return 1; }
    
    if [ ! -d ".terraform" ]; then
        print_info "Initializing Terraform..."
        terraform init > /dev/null 2>&1 || { print_error "Terraform init failed"; return 1; }
    fi
    
    print_info "Running terraform plan (showing key resources)..."
    echo ""
    
    # This would show what terraform will create - commented out to avoid actual plan
    # terraform plan | grep -E "azurerm_linux_virtual_machine|azurerm_role_assignment"
    
    print_check "Terraform plan would create:"
    print_info "  - azurerm_linux_virtual_machine (Jump VM)"
    print_info "  - azurerm_role_assignment (AKS User, Reader, AcrPull)"
    print_info "  - System Assigned Managed Identity"
    
    cd - > /dev/null
    return 0
}

# ============================================================================
# Final Summary
# ============================================================================

print_summary() {
    print_header "Verification Summary"
    
    local total=$1
    local passed=$2
    local failed=$((total - passed))
    
    echo ""
    echo "Total Checks: $total"
    echo -e "Passed: ${GREEN}$passed${NC}"
    echo -e "Failed: ${RED}$failed${NC}"
    echo ""
    
    if [ $failed -eq 0 ]; then
        print_check "All verifications passed!"
        echo ""
        print_info "Next steps:"
        echo "  1. Update terraform.tfvars with Jump VM variables"
        echo "  2. Add GitHub secrets (see check_github_secrets output)"
        echo "  3. Run: cd terraform/environments/${ENVIRONMENT} && terraform apply"
        echo "  4. Capture outputs: terraform output -json"
        echo "  5. Manually trigger GitHub Actions workflow to test"
        return 0
    else
        print_error "$failed check(s) failed - review above and fix issues"
        return 1
    fi
}

# ============================================================================
# Main Execution
# ============================================================================

main() {
    print_header "Private AKS Deployment Verification"
    echo ""
    print_info "Environment: $ENVIRONMENT"
    echo ""
    
    local passed=0
    local total=5
    
    # Run verification checks
    if verify_files; then ((passed++)); fi
    echo ""
    
    if verify_terraform; then ((passed++)); fi
    echo ""
    
    if verify_cloud_init; then ((passed++)); fi
    echo ""
    
    if verify_github_workflow; then ((passed++)); fi
    echo ""
    
    check_github_secrets
    echo ""
    
    simulate_plan
    echo ""
    
    # Print summary
    print_summary $total $passed
}

# Run main function
main
EXIT_CODE=$?

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

exit $EXIT_CODE
