# AKS Jump VM Bootstrap - Quick Reference Guide

## TL;DR - What Changed?

Three things:
1. **Cloud-Init Enhanced**: Better logging, idempotency, completion markers
2. **Terraform Updated**: More reliable VM replacement when cloud-init changes
3. **GitHub Actions**: New validation workflow to check bootstrap before deployment

**Result**: No more mysterious "/opt/deploy/deploy.sh: not found" errors

---

## Quick Start: Deploy the Fix

### Step 1: Apply Terraform Changes (15 mins)

```bash
cd terraform/environments/dev

# See the changes
terraform plan

# Apply (VM will be recreated)
terraform apply

# Terraform will output:
# ✓ VM replaced
# ✓ New outputs added
# ✓ Terraform state updated
```

### Step 2: Monitor Bootstrap (10-15 mins)

```bash
# Option A: SSH to VM
ssh azureuser@<jump-vm-public-ip>
tail -f /var/log/bootstrap-jumpvm.log
# Wait for: "✅ Bootstrap Completed Successfully"

# Option B: GitHub Actions workflow
# Go to: Actions > jumpvm-bootstrap-validation > Run workflow
# Check all stages pass
```

### Step 3: Validate Deployment (5 mins)

```bash
# Run deployment workflow
# Go to: Actions > Build, Push, and Deploy to Private AKS > Run workflow

# Should complete with no errors
# Check: Application pods running in AKS
kubectl get pods -n employee-management
```

**Done!** ✅

---

## Common Commands

### Check Bootstrap Status

```bash
# From your local machine
JUMP_VM_NAME="<your-vm-name>"
RESOURCE_GROUP="<your-rg>"

# Check if marker exists
az vm run-command invoke \
  --resource-group "$RESOURCE_GROUP" \
  --name "$JUMP_VM_NAME" \
  --command-id RunShellScript \
  --scripts "ls -lh /opt/deploy/.bootstrap-complete"
```

### View Bootstrap Logs

```bash
# SSH to VM
ssh azureuser@<jump-vm-public-ip>

# View bootstrap log
tail -100 /var/log/bootstrap-jumpvm.log

# View cloud-init log
tail -50 /var/log/cloud-init-output.log

# View failure diagnostics (if failed)
cat /opt/deploy/.bootstrap-diagnostics
```

### Verify Tools

```bash
# SSH to VM
ssh azureuser@<jump-vm-public-ip>

# Test each tool
kubectl version --client   # Should succeed
helm version               # Should succeed
kubelogin --version       # Should succeed
az version                # Should succeed

# All output should show version info (no errors)
```

### Verify Deploy Script

```bash
# SSH to VM
ssh azureuser@<jump-vm-public-ip>

# Check if script exists
ls -lh /opt/deploy/deploy.sh

# Check if executable
test -x /opt/deploy/deploy.sh && echo "✅ Executable" || echo "❌ Not executable"

# View first few lines
head -20 /opt/deploy/deploy.sh
```

---

## Troubleshooting Flowchart

```
Problem: /opt/deploy/deploy.sh: not found

1. Is VM running?
   └─ az vm list -g <rg> --query "[].powerState"
      └─ NO → Start the VM
      └─ YES → Continue to 2

2. Is cloud-init still running?
   └─ az vm run-command invoke ... scripts "cloud-init status"
      └─ Running → Wait and try again
      └─ Done → Continue to 3

3. Check bootstrap marker
   └─ SSH and check: ls /opt/deploy/.bootstrap-complete
      └─ Exists → deploy.sh should exist, check permissions
      └─ Missing → Bootstrap failed, check logs

4. Check bootstrap logs
   └─ SSH and check: tail -100 /var/log/bootstrap-jumpvm.log
      └─ Errors → See "Common Issues" section below

5. Check diagnostics
   └─ SSH and check: cat /opt/deploy/.bootstrap-diagnostics
      └─ Shows what failed → Take action from "Common Issues"
```

---

## Common Issues & Fixes

### Issue 1: "Apt lock held" Error

**Log output**:
```
ERROR: Timeout waiting for apt locks
```

**Fix**:
```bash
# SSH to VM
ssh azureuser@<jump-vm-public-ip>

# Release locks
sudo lsof /var/lib/apt/lists/lock | awk '{print $2}' | tail -1 | xargs sudo kill -9 2>/dev/null || true
sudo rm -f /var/lib/apt/lists/lock
sudo apt-get update

# Retry bootstrap
sudo /usr/local/sbin/bootstrap-jumpvm.sh
```

### Issue 2: "Insufficient Disk Space"

**Log output**:
```
Insufficient disk space (need 1GB, have 512MB)
```

**Fix**:
```bash
# SSH to VM
ssh azureuser@<jump-vm-public-ip>

# Check disk space
df -h /

# Clean up
sudo apt-get clean
sudo apt-get autoclean
sudo rm -rf /tmp/*

# Retry bootstrap
sudo /usr/local/sbin/bootstrap-jumpvm.sh
```

### Issue 3: "Network Timeout"

**Log output**:
```
ERROR: Failed to download kubectl
```

**Fix**:
```bash
# SSH to VM
ssh azureuser@<jump-vm-public-ip>

# Check connectivity
ping -c 1 google.com
curl -I https://dl.k8s.io/

# If network is down:
# - Check VM's Network Security Group
# - Check Azure network connectivity
# - Check DNS resolution

# Retry bootstrap
sudo /usr/local/sbin/bootstrap-jumpvm.sh
```

### Issue 4: "Tool Installation Failed"

**Log output**:
```
ERROR: kubectl was not installed
```

**Fix**:
```bash
# SSH to VM
ssh azureuser@<jump-vm-public-ip>

# Check what's missing
which kubectl helm kubelogin az

# Manually reinstall missing tool
# Or re-run bootstrap:
sudo /usr/local/sbin/bootstrap-jumpvm.sh
```

### Issue 5: "deploy.sh Not Executable"

**SSH output**:
```
-rw-r--r-- 1 root root /opt/deploy/deploy.sh
                ^
                Not executable (+x missing)
```

**Fix**:
```bash
# SSH to VM
ssh azureuser@<jump-vm-public-ip>

# Fix permissions
sudo chmod 755 /opt/deploy/deploy.sh

# Verify
ls -lh /opt/deploy/deploy.sh
# Should show: -rwxr-xr-x
```

---

## GitHub Actions Troubleshooting

### Workflow Fails at "Check Bootstrap Marker"

**Cause**: Bootstrap hasn't completed within 10 minutes

**Solution**:
1. SSH to VM: `ssh azureuser@<ip>`
2. Check logs: `tail -100 /var/log/bootstrap-jumpvm.log`
3. Look for errors (see "Common Issues" above)
4. Fix issue
5. Re-run bootstrap: `sudo /usr/local/sbin/bootstrap-jumpvm.sh`
6. Re-run GitHub Actions workflow

### Workflow Fails at "Verify Tool Installation"

**Cause**: One or more tools not installed

**Solution**:
1. Check which tool is missing: Review GitHub Actions log output
2. SSH to VM: `ssh azureuser@<ip>`
3. Check what's installed: `which kubectl helm kubelogin az`
4. Check logs: `grep -i "install_<tool>" /var/log/bootstrap-jumpvm.log`
5. Manually install or re-run bootstrap

### Workflow Fails at "Retrieve Bootstrap Logs"

**Cause**: Cannot access VM via Azure CLI

**Solution**:
1. Check VM is running: `az vm list -g <rg>`
2. Check credentials: Ensure `${{ secrets.AZURE_CREDENTIALS }}` is correct
3. Check NSG rules: VM must be accessible
4. Check resource group name: Must match exactly

---

## Maintenance Tasks

### Update Tool Versions

**Goal**: Update kubectl or kubelogin version

```bash
cd terraform/environments/dev

# Edit terraform.tfvars
vi terraform.tfvars

# Change:
# TF_VAR_kubectl_version = "v1.29.0"
# TF_VAR_kubelogin_version = "v0.0.14"

# Plan (VM will be replaced)
terraform plan

# Apply (VM will be recreated with new tools)
terraform apply

# Monitor bootstrap (see "Monitor Bootstrap" section)
```

### Rotate SSH Keys

**Note**: Requires VM replacement (not a quick operation)

```bash
# In terraform/environments/dev/terraform.tfvars:
# Update: TF_VAR_jumpvm_ssh_public_key = "ssh-rsa <new-key>"

# Then:
terraform plan
terraform apply

# VM will be recreated with new SSH key
```

### Update Cloud-Init Script

**Goal**: Add new script or modify existing script

```bash
# Edit the script:
vi terraform/scripts/jumpvm-cloud-init-enhanced.yaml

# Plan (VM will be replaced due to cloud-init hash change)
terraform plan

# Apply
terraform apply
```

---

## Rollback Procedure

**If something goes wrong**:

### Quick Rollback (Keep Current VM)

```bash
# This doesn't actually roll back, but prevents further changes

# 1. Revert the cloud-init file change
git checkout HEAD~1 -- terraform/scripts/jumpvm-cloud-init-enhanced.yaml

# 2. Plan and apply
terraform plan
# Should show no changes (or minimal changes)

terraform apply

# The lifecycle rule WON'T trigger replacement (hash unchanged)
# So current VM is preserved with current state
```

### Full Rollback (Recreate VM from Old Cloud-Init)

```bash
# 1. Check out old cloud-init
git checkout HEAD~1 -- terraform/

# 2. Point to old script in terraform/modules/vm/main.tf:
# Change: file("...jumpvm-cloud-init-enhanced.yaml")
# To:     file("...jumpvm-cloud-init.yaml")

# 3. Plan (VM will be replaced)
terraform plan

# 4. Apply (old VM destroyed, new VM created with old cloud-init)
terraform apply

# 5. Verify bootstrap completed (see "Validate Bootstrap" section)
```

---

## Performance Checklist

- [ ] Bootstrap completes in < 5 minutes
- [ ] All tools installed successfully
- [ ] Deployment succeeds without timeout
- [ ] Application pods start within 2 minutes
- [ ] kubectl can access AKS cluster
- [ ] No errors in bootstrap logs
- [ ] No warnings in GitHub Actions workflow

---

## Production Deployment Checklist

- [ ] Reviewed AKS_JUMPVM_PRODUCTION_FIX.md
- [ ] Backed up current Terraform state
- [ ] Backed up current cloud-init script
- [ ] Scheduled maintenance window
- [ ] Notified team
- [ ] Tested changes in dev environment first
- [ ] Reviewed all log files
- [ ] Performed pre-deployment validation
- [ ] Applied Terraform changes
- [ ] Monitored bootstrap completion
- [ ] Validated GitHub Actions workflows
- [ ] Tested application functionality
- [ ] Documented any issues encountered
- [ ] Created runbook for future maintenance

---

## Key Files

| File | Purpose |
|------|---------|
| `terraform/scripts/jumpvm-cloud-init-enhanced.yaml` | Main bootstrap script |
| `terraform/modules/vm/main.tf` | VM resource with lifecycle |
| `.github/workflows/jumpvm-bootstrap-validation.yml` | Bootstrap validation |
| `AKS_JUMPVM_PRODUCTION_FIX.md` | Full documentation |
| `AKS_JUMPVM_CODE_CHANGES.md` | Code change details |

---

## Getting Help

### Self-Service Resources

1. Check troubleshooting flowchart (above)
2. Review common issues (above)
3. SSH to VM and check logs
4. Review GitHub Actions workflow logs
5. Check Azure portal for VM status

### Escalation

If self-service doesn't work:

1. Collect diagnostics:
   ```bash
   # From GitHub Actions workflow output:
   # - Bootstrap validation output
   # - Tool verification results
   
   # From VM (via SSH):
   # - /var/log/bootstrap-jumpvm.log
   # - /var/log/cloud-init-output.log
   # - /opt/deploy/.bootstrap-diagnostics
   # - terraform plan output
   ```

2. Create GitHub issue with:
   - Problem description
   - All diagnostics collected above
   - Steps taken so far
   - Expected vs. actual behavior

3. Team will investigate and provide guidance

---

## Key Metrics to Monitor

After deployment:

- **Bootstrap time**: < 5 minutes ✅
- **Tool availability**: All 4 tools present ✅
- **Deployment time**: < 15 minutes ✅
- **Pod startup time**: < 2 minutes ✅
- **Error rate in logs**: 0% ✅

---

## Phone Home (Future Enhancement)

Future versions could include:

- Slack notifications on bootstrap completion
- Prometheus metrics for bootstrap duration
- Automated diagnostics upload to Azure Blob Storage
- CloudWatch logs integration (if using AWS)
- PagerDuty alerts on bootstrap failure

Currently: Manual monitoring via GitHub Actions UI and logs

---

## Questions?

Refer to:
- **Full docs**: `AKS_JUMPVM_PRODUCTION_FIX.md`
- **Code changes**: `AKS_JUMPVM_CODE_CHANGES.md`
- **Terraform code**: `terraform/modules/vm/`
- **Cloud-init**: `terraform/scripts/jumpvm-cloud-init-enhanced.yaml`
- **GitHub Actions**: `.github/workflows/jumpvm-bootstrap-validation.yml`

**Last Updated**: 2024-06-19
**Version**: 1.0
**Status**: Production-Ready ✅
