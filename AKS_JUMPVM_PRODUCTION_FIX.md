# AKS Jump VM Bootstrap - Production-Grade Fix Documentation

## Executive Summary

This document provides a comprehensive, production-grade fix for the Terraform + Azure Private AKS + Jump VM deployment architecture. The solution addresses critical gaps in cloud-init bootstrap, VM lifecycle management, GitHub Actions validation, and operational diagnostics.

---

## PART 1: ROOT CAUSE ANALYSIS

### Primary Issue: `/opt/deploy/deploy.sh: not found`

The failure was caused by a cascade of issues:

#### 1. Cloud-Init Execution Reliability (Root Cause)
- **Problem**: Cloud-init runs asynchronously without completion markers
- **Impact**: GitHub Actions couldn't determine if bootstrap completed
- **Result**: Workflow attempts deployment before tools are installed

```
Timeline:
  T+0s:   VM starts, cloud-init runs
  T+30s:  GitHub Actions checks for deploy.sh (FAILS - not created yet)
  T+600s: Timeout, deployment fails
  T+900s: Cloud-init finally completes (TOO LATE)
```

#### 2. Idempotency Not Implemented
- **Problem**: Cloud-init runs on every boot without checking previous completion
- **Risk**: Tools could be partially installed if previous run interrupted
- **Issue**: No detection of partial/failed bootstrap

#### 3. Inadequate Logging
- **Problem**: No centralized bootstrap status tracking
- **Impact**: Failures produce unhelpful error messages
- **Difficulty**: Troubleshooting requires SSH access to VM

#### 4. VM Recreation Not Reliable
- **Problem**: `terraform_data.jumpvm_cloud_init` resource references may not properly trigger replacement
- **Impact**: Cloud-init changes don't guarantee VM replacement
- **Result**: Old VMs retain outdated tool versions

#### 5. GitHub Actions Blind Wait
- **Problem**: Workflow waits 10 minutes without intermediate checks
- **Impact**: Slow failure feedback loop
- **UX**: No insight into what's happening

---

## PART 2: PRODUCTION-GRADE SOLUTION OVERVIEW

### Architecture: Three-Layer Fix

```
Layer 1: Cloud-Init Enhancement
├── Idempotency checks
├── Bootstrap completion markers
├── Structured logging
├── Tool validation
└── Error aggregation

Layer 2: Terraform Improvements
├── Reliable VM replacement triggers
├── Cloud-init hash-based lifecycle
├── Bootstrap status outputs
└── Validation in outputs

Layer 3: GitHub Actions Enhancement
├── Multi-stage validation
├── Tool availability checks
├── Log retrieval on failure
├── Clear diagnostics
└── Failure recovery guidance
```

---

## PART 3: IMPLEMENTATION CHANGES

### 3.1 Cloud-Init Enhanced Script

**File**: `terraform/scripts/jumpvm-cloud-init-enhanced.yaml`

**Key Features**:

1. **Idempotency Guard**
```bash
check_idempotency() {
  if [ -f "${BOOTSTRAP_MARKER}" ]; then
    log "Bootstrap previously completed, skipping re-initialization"
    return 0
  fi
  return 1
}
```

2. **Completion Marker**
```bash
create_bootstrap_marker() {
  touch "${BOOTSTRAP_MARKER}"  # /opt/deploy/.bootstrap-complete
}
```

3. **Structured Logging**
- `/var/log/bootstrap-jumpvm.log` - Detailed operations
- `/opt/deploy/.bootstrap-diagnostics` - Failure diagnostics
- `/var/log/cloud-init-output.log` - Cloud-init wrapper logs

4. **Tool Validation**
```bash
validate_installation() {
  for tool in az kubectl helm kubelogin; do
    command -v "${tool}" >/dev/null || fail "${tool} not found"
  done
}
```

5. **Error Aggregation**
```bash
emit_diagnostics_on_failure() {
  # Collects system resources, installed tools, directory structure
  # Emits to /opt/deploy/.bootstrap-diagnostics
}
```

### 3.2 Terraform VM Module Updates

**File**: `terraform/modules/vm/main.tf`

**Changes**:

1. **Hash-Based Lifecycle Trigger** (More reliable)
```hcl
locals {
  jumpvm_cloud_init_hash = base64sha256(local.jumpvm_cloud_init)
}

lifecycle {
  replace_triggered_by = [
    local.jumpvm_cloud_init_hash  # Direct reference, not terraform_data
  ]
}
```

2. **Enhanced Outputs** (for GitHub Actions)
```hcl
output "bootstrap_marker_path" {
  value = "/opt/deploy/.bootstrap-complete"
  description = "Path to bootstrap completion marker"
}

output "bootstrap_log_path" {
  value = "/var/log/bootstrap-jumpvm.log"
  description = "Path to bootstrap execution log"
}

output "expected_tools" {
  value = {
    kubectl  = var.kubectl_version
    kubelogin = var.kubelogin_version
    helm     = "latest"
    azure_cli = "latest"
  }
}
```

### 3.3 GitHub Actions Bootstrap Validation Workflow

**File**: `.github/workflows/jumpvm-bootstrap-validation.yml`

**Four-Stage Validation**:

```
Stage 1: Check Bootstrap Marker
  └─ Polls /opt/deploy/.bootstrap-complete (up to 10 minutes)

Stage 2: Verify Tool Installation  
  └─ Tests: kubectl, helm, kubelogin, az
  
Stage 3: Verify deploy.sh Script
  └─ Checks existence, executability, content
  
Stage 4: Retrieve Diagnostics (on failure)
  └─ Captures logs and system state
```

---

## PART 4: IMPLEMENTATION STEPS

### Step 1: Update Cloud-Init Script

```bash
# Backup old script
cp terraform/scripts/jumpvm-cloud-init.yaml \
   terraform/scripts/jumpvm-cloud-init.yaml.bak

# Use new enhanced script
# File: terraform/scripts/jumpvm-cloud-init-enhanced.yaml
# is ready for deployment
```

### Step 2: Update Terraform VM Module

```bash
cd terraform/modules/vm

# The following changes have been made:
# 1. ✅ Updated locals block with jumpvm_cloud_init_hash
# 2. ✅ Updated lifecycle rule to use hash directly
# 3. ✅ Removed terraform_data.jumpvm_cloud_init resource
# 4. ✅ Added bootstrap status outputs
```

### Step 3: Add GitHub Actions Bootstrap Validation

```bash
# New file created:
# .github/workflows/jumpvm-bootstrap-validation.yml

# This workflow:
# - Runs after Terraform apply completes
# - Validates bootstrap completion before deployment
# - Retrieves logs on failure
```

### Step 4: Update Terraform Configuration

Edit `terraform/environments/dev/main.tf` to use enhanced cloud-init:

```hcl
module "jump_vm" {
  source = "../../modules/vm"
  
  # ... other variables ...
  
  # Point to enhanced cloud-init script
  # The module now references:
  # file("${path.module}/../../scripts/jumpvm-cloud-init-enhanced.yaml")
}
```

### Step 5: Apply Changes

```bash
cd terraform/environments/dev

# Plan changes
terraform plan

# Key items to expect:
# - azurerm_linux_virtual_machine.jumpvm will be replaced
#   (because cloud-init hash changed)
# - New outputs added for bootstrap status
# - VM will be destroyed and recreated with new bootstrap script

# Apply changes
terraform apply
```

---

## PART 5: VALIDATION PROCEDURES

### Validation 1: Verify Bootstrap Completion (Immediate)

```bash
# After terraform apply completes, SSH to Jump VM

# Check marker file
ssh azureuser@<jump-vm-public-ip>
ls -lh /opt/deploy/.bootstrap-complete

# Should output:
# -rw-r--r-- 1 root root    0 2024-06-19 14:23:45.123456789 +0000 /opt/deploy/.bootstrap-complete
```

### Validation 2: Verify Tool Installation

```bash
# SSH to Jump VM
ssh azureuser@<jump-vm-public-ip>

# Test each tool
kubectl version --client
helm version
kubelogin --version
az version

# All should succeed without errors
```

### Validation 3: Verify Deploy Script

```bash
# SSH to Jump VM
ssh azureuser@<jump-vm-public-ip>

# Check script
ls -lh /opt/deploy/deploy.sh
head -20 /opt/deploy/deploy.sh

# Should be executable and contain deployment logic
```

### Validation 4: Review Bootstrap Logs

```bash
# SSH to Jump VM
ssh azureuser@<jump-vm-public-ip>

# Bootstrap script log
tail -100 /var/log/bootstrap-jumpvm.log
# Should show: "✅ Bootstrap Completed Successfully"

# Cloud-init log
tail -50 /var/log/cloud-init-output.log

# Check for failures
grep -i error /var/log/bootstrap-jumpvm.log
# Should be empty (or only INFO level)
```

### Validation 5: Test GitHub Actions Workflow

```bash
# Manually trigger bootstrap validation workflow
# GitHub Actions > jumpvm-bootstrap-validation > Run workflow

# Should complete with:
# ✅ Bootstrap Complete: true
# ✅ kubectl Available: available
# ✅ helm Available: available
# ✅ kubelogin Available: available
# ✅ Azure CLI Available: available
```

---

## PART 6: TROUBLESHOOTING GUIDE

### Symptom: Bootstrap Marker Not Created

**Diagnostic Steps**:

```bash
# 1. SSH to Jump VM
ssh azureuser@<jump-vm-public-ip>

# 2. Check cloud-init status
cloud-init status
# Should show: status: done

# 3. Review bootstrap log
tail -200 /var/log/bootstrap-jumpvm.log
# Look for ERROR or WARN lines

# 4. Check system resources
free -h      # Memory
df -h /      # Disk space
lsof /var/lib/apt/lists/lock  # Apt lock

# 5. Check diagnostics file
cat /opt/deploy/.bootstrap-diagnostics
```

**Common Causes**:

| Symptom | Root Cause | Fix |
|---------|-----------|-----|
| "Apt lock held" error | Previous apt operation interrupted | `rm -f /var/lib/apt/lists/lock; apt-get update` |
| Insufficient disk space | Too many failed apt operations | Free disk space, then re-run bootstrap |
| Network timeout | Download failures | Check VM network connectivity |
| Tool not installed | Installation script error | Review specific tool section in log |

### Symptom: Deploy.sh Not Executable

**Fix**:

```bash
# SSH to Jump VM
ssh azureuser@<jump-vm-public-ip>

# Fix permissions
sudo chmod 755 /opt/deploy/deploy.sh

# Verify
ls -lh /opt/deploy/deploy.sh
```

### Symptom: GitHub Actions Validation Timeout

**Diagnostic Steps**:

```bash
# 1. Check if VM is running
az vm list -g <resource-group> --query "[].{Name:name, PowerState:powerState}"

# 2. Check if cloud-init is still running
az vm run-command invoke \
  --resource-group <resource-group> \
  --name <vm-name> \
  --command-id RunShellScript \
  --scripts "cloud-init status" \
  --query 'value[0].message' \
  --output tsv

# 3. SSH and review logs (see above)
```

---

## PART 7: ROLLBACK STRATEGY

### Rollback to Previous Cloud-Init

If the enhanced cloud-init causes issues:

```bash
cd terraform/environments/dev

# Edit terraform.tfvars or .tfvars file
# Or directly edit modules/vm/main.tf to use old cloud-init

# Revert to old script
# Change: file("${path.module}/../../scripts/jumpvm-cloud-init-enhanced.yaml")
# To:     file("${path.module}/../../scripts/jumpvm-cloud-init.yaml")

# This will NOT trigger VM replacement (hash unchanged)
# To force replacement, run:
terraform taint azurerm_linux_virtual_machine.jumpvm

# Apply
terraform apply
```

### Rollback to Previous VM

If you need to preserve the VM but revert cloud-init changes:

```bash
# Note: The lifecycle rule will force destruction on cloud-init changes
# To keep current VM and skip updates:

# 1. Remove the lifecycle rule temporarily
# 2. Apply changes
# 3. SSH and manually install/update tools
# 4. Re-enable lifecycle rule

# Or: Create new VM with old cloud-init via terraform apply
# Old VM will be destroyed (per lifecycle rule)
```

---

## PART 8: PRODUCTION BEST PRACTICES

### 1. Cloud-Init Idempotency

✅ **DO**: Check for completion markers at start of bootstrap

```bash
if [ -f /opt/deploy/.bootstrap-complete ]; then
  log "Bootstrap already completed, skipping"
  exit 0
fi
```

❌ **DON'T**: Assume bootstrap hasn't run

### 2. Tool Version Validation

✅ **DO**: Verify tool versions match expected versions

```bash
INSTALLED=$(kubectl version --client -o json | jq -r '.clientVersion.gitVersion')
if [ "${INSTALLED}" != "${EXPECTED}" ]; then
  # Update or fail
fi
```

❌ **DON'T**: Assume tool is correct version

### 3. Error Logging

✅ **DO**: Aggregate all errors for post-mortem analysis

```bash
emit_diagnostics_on_failure() {
  # Capture system state, logs, installed tools
  # Write to /opt/deploy/.bootstrap-diagnostics
}
```

❌ **DON'T**: Log silently and fail without diagnostics

### 4. Staged Validation

✅ **DO**: Validate in stages with checkpoints

```
Stage 1: Marker exists
Stage 2: Tools installed
Stage 3: Scripts executable
Stage 4: Functionality (test connectivity)
```

❌ **DON'T**: Single validation point (all or nothing)

### 5. Azure-Specific Concerns

✅ **DO**: Handle Apt lock conflicts (common in Azure)

```bash
while fuser /var/lib/dpkg/lock >/dev/null 2>&1; do
  sleep 2
done
```

❌ **DON'T**: Assume apt is available immediately

---

## PART 9: TESTING CHECKLIST

Before deploying to production:

- [ ] Run `terraform plan` and verify cloud-init change detected
- [ ] Run `terraform apply` and verify VM is replaced
- [ ] Wait for cloud-init to complete (check logs)
- [ ] Manually validate bootstrap (SSH and test tools)
- [ ] Run GitHub Actions bootstrap validation workflow
- [ ] Run GitHub Actions deployment workflow
- [ ] Verify Helm deployment succeeded
- [ ] Check application pods are running
- [ ] Review all logs for warnings/errors
- [ ] Test application functionality end-to-end

---

## PART 10: FILES CHANGED

### New Files Created

```
✅ terraform/scripts/jumpvm-cloud-init-enhanced.yaml
   - Enhanced cloud-init with idempotency and logging

✅ .github/workflows/jumpvm-bootstrap-validation.yml
   - Bootstrap validation workflow for GitHub Actions
```

### Files Modified

```
✅ terraform/modules/vm/main.tf
   - Updated locals block with jumpvm_cloud_init_hash
   - Updated lifecycle rule for reliable VM replacement
   - Removed terraform_data.jumpvm_cloud_init

✅ terraform/modules/vm/outputs-identity.tf
   - Added bootstrap status outputs
   - Added cloud-init version and tool information
```

---

## PART 11: PRODUCTION DEPLOYMENT TIMELINE

### Phase 1: Preparation (30 minutes)
- [ ] Review this documentation
- [ ] Backup current Terraform state
- [ ] Backup current cloud-init script
- [ ] Review GitHub Actions workflow changes
- [ ] Communicate with team about upcoming maintenance

### Phase 2: Apply Infrastructure Changes (15 minutes)
```bash
cd terraform/environments/dev
terraform plan          # Review changes
terraform apply         # Apply (VM will be destroyed/recreated)
```

### Phase 3: Validate Bootstrap (10-15 minutes)
```bash
# Monitor cloud-init on VM
# Check bootstrap marker
# SSH and test tools
# Review logs
```

### Phase 4: Validate Workflows (5-10 minutes)
```bash
# Run bootstrap validation workflow
# Run deployment workflow
# Verify application is running
```

### Phase 5: Post-Deployment Verification (10 minutes)
- [ ] Check application logs
- [ ] Verify data consistency
- [ ] Test application functionality
- [ ] Document any issues

**Total Time**: ~70-80 minutes

---

## PART 12: SUCCESS CRITERIA

Deployment is successful when:

1. ✅ VM is created with enhanced cloud-init
2. ✅ `/opt/deploy/.bootstrap-complete` exists
3. ✅ All tools installed: kubectl, helm, kubelogin, az
4. ✅ `/opt/deploy/deploy.sh` is executable
5. ✅ `/var/log/bootstrap-jumpvm.log` shows successful completion
6. ✅ GitHub Actions bootstrap validation workflow passes
7. ✅ GitHub Actions deployment workflow succeeds
8. ✅ Application pods are running in AKS cluster
9. ✅ No errors in bootstrap logs
10. ✅ Tools can connect to AKS cluster

---

## PART 13: SUPPORT AND TROUBLESHOOTING

### Getting Help

If issues occur:

1. **Check diagnostics file**
   ```bash
   ssh azureuser@<vm> cat /opt/deploy/.bootstrap-diagnostics
   ```

2. **Review bootstrap log**
   ```bash
   ssh azureuser@<vm> tail -200 /var/log/bootstrap-jumpvm.log
   ```

3. **Review cloud-init output**
   ```bash
   ssh azureuser@<vm> tail -100 /var/log/cloud-init-output.log
   ```

4. **Check GitHub Actions workflow logs**
   - Navigate to Actions > jumpvm-bootstrap-validation
   - Review output from each stage

5. **Create GitHub issue with**
   - terraform plan output
   - Bootstrap log tail
   - Diagnostics file content
   - GitHub Actions workflow run logs

---

## Conclusion

This production-grade fix addresses all identified issues with the Jump VM bootstrap architecture. The solution is:

- **Reliable**: Multiple validation stages and completion markers
- **Idempotent**: Safe to run multiple times
- **Observable**: Comprehensive logging and diagnostics
- **Maintainable**: Clear structure and documentation
- **Production-Ready**: Follows Azure and HashiCorp best practices

The three-layer approach (Cloud-Init → Terraform → GitHub Actions) ensures robustness at each level of the infrastructure stack.
