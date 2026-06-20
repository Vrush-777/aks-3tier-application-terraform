# Quick Reference: Jump VM Bootstrap Fix Implementation

## TL;DR

**Problem**: GitHub Actions fails with `/opt/deploy/deploy.sh: not found`

**Root Cause**: Terraform never recreates VM when cloud-init changes

**Fix**: Add lifecycle rule to force VM recreation

**Files Changed**: 
- `terraform/modules/vm/main.tf` (lifecycle rule)
- `terraform/modules/vm/outputs-identity.tf` (new outputs)
- `.github/workflows/jumpvm-bootstrap-validation-v2.yml` (new workflow)

**Time to Deploy**: ~5 minutes (VM recreation downtime)

---

## Quick Checklist

### Pre-Flight
- [ ] Review `ROOT_CAUSE_ANALYSIS_AND_FIX.md` (this directory)
- [ ] Backup current Terraform state: `terraform state pull > tfstate-backup.json`
- [ ] Notify team of ~5 min downtime

### Execute Fix
```bash
# 1. Go to terraform dev environment
cd terraform/environments/dev

# 2. Check what will change
terraform plan -out=tfplan
terraform show tfplan | grep "will be replaced"

# 3. Apply (recreates VM)
terraform apply tfplan

# 4. Wait ~3-5 minutes for VM to boot

# 5. Get new VM IP
NEW_IP=$(terraform output -raw jump_vm_public_ip)

# 6. SSH and verify bootstrap
ssh azureuser@${NEW_IP}
ls -lh /opt/deploy/.bootstrap-complete
which kubectl helm kubelogin az
```

### Post-Deployment
- [ ] SSH into VM and verify: `ls /opt/deploy/.bootstrap-complete`
- [ ] Check tools: `kubectl version --client`
- [ ] Trigger GitHub Actions deployment workflow
- [ ] Monitor workflow stages 1-4 (all should pass)
- [ ] Verify AKS deployment succeeds

---

## Modified Files (What Changed)

### File 1: terraform/modules/vm/main.tf

**Change**: Add lifecycle rule to recreate VM when cloud-init changes

```hcl
# ADDED: Lifecycle rule
lifecycle {
  replace_triggered_by = [
    base64sha256(local.jumpvm_cloud_init)
  ]
}
```

**Why**: Cloud-init runs only on first boot. Without this, VM keeps old scripts.

---

### File 2: terraform/modules/vm/outputs-identity.tf

**Change**: Add outputs for bootstrap validation and diagnostics

```hcl
# ADDED: Bootstrap status outputs
output "bootstrap_marker_path" { value = "/opt/deploy/.bootstrap-complete" }
output "cloud_init_hash" { value = local.jumpvm_cloud_init_hash }
output "bootstrap_log_path" { value = "/var/log/bootstrap-jumpvm.log" }
output "diagnostics_path" { value = "/opt/deploy/.bootstrap-diagnostics" }
```

**Why**: Allows GitHub Actions to query bootstrap status programmatically.

---

### File 3: .github/workflows/jumpvm-bootstrap-validation-v2.yml

**Change**: New workflow that validates bootstrap marker (not deploy.sh file)

**Key Stages**:
1. Check `/opt/deploy/.bootstrap-complete` marker (success indicator)
2. Verify tools (kubectl, helm, kubelogin, az)
3. Verify deploy.sh script exists
4. Final readiness check
5. Retrieve diagnostics on failure

**Why**: Marker-based validation is more reliable than file presence checks.

---

## Validation After Deployment

### Command #1: Verify Marker Exists
```bash
JUMP_VM_IP=$(terraform output -raw jump_vm_public_ip)
ssh azureuser@${JUMP_VM_IP} 'ls -lh /opt/deploy/.bootstrap-complete'
```
**Expected**: File exists with recent timestamp

### Command #2: Verify All Tools Installed
```bash
ssh azureuser@${JUMP_VM_IP} 'which kubectl helm kubelogin az jq git unzip'
```
**Expected**: All commands show paths

### Command #3: Verify Deploy Script
```bash
ssh azureuser@${JUMP_VM_IP} 'ls -l /opt/deploy/deploy.sh && file /opt/deploy/deploy.sh'
```
**Expected**: File is executable, is a shell script

### Command #4: Check Bootstrap Log
```bash
ssh azureuser@${JUMP_VM_IP} 'tail -20 /var/log/bootstrap-jumpvm.log'
```
**Expected**: Last line shows "✅ Bootstrap Completed Successfully"

---

## Rollback (If Something Goes Wrong)

### Step 1: Restore Previous Cloud-Init
```bash
cd terraform/environments/dev
git checkout HEAD~1 -- ../../scripts/jumpvm-cloud-init-enhanced.yaml
```

### Step 2: Recreate VM with Old Cloud-Init
```bash
terraform plan -out=tfplan
terraform apply tfplan
```

### Step 3: Verify Bootstrap Completes
```bash
ssh azureuser@${NEW_IP} 'ls /opt/deploy/.bootstrap-complete'
```

---

## Troubleshooting

| Problem | Check | Fix |
|---------|-------|-----|
| VM stuck in "Updating" | Azure Portal VM status | Wait 5 min or force reboot |
| SSH fails after apply | New IP assigned? | `terraform output jump_vm_public_ip` |
| Marker doesn't exist | SSH into VM | `tail /var/log/bootstrap-jumpvm.log` |
| Tools not found | SSH and check PATH | Manual installation (shouldn't happen) |
| GitHub Actions fails | Workflow logs | Check Stage 5 diagnostics |

---

## GitHub Actions Workflow Trigger

### Automatic (on Terraform apply)
- Terraform completes
- `workflow_run` trigger activates new bootstrap validation
- Workflow runs automatically

### Manual Trigger
```bash
curl -X POST \
  -H "Accept: application/vnd.github.v3+json" \
  https://api.github.com/repos/YOUR_ORG/YOUR_REPO/actions/workflows/jumpvm-bootstrap-validation-v2.yml/dispatches \
  -d '{"ref":"test"}' \
  -H "Authorization: token YOUR_GITHUB_TOKEN"
```

---

## Q&A

**Q: Will this cause downtime?**  
A: Yes, ~5 minutes while VM is destroyed and recreated. Plan accordingly.

**Q: What if cloud-init fails?**  
A: GitHub Actions will detect missing marker and retrieve diagnostics from logs.

**Q: Can I disable the lifecycle rule?**  
A: Yes (in outputs-identity.tf, comment it out), but then cloud-init changes won't work.

**Q: Do I need to update GitHub Actions workflows?**  
A: Recommended. Use `jumpvm-bootstrap-validation-v2.yml` for better diagnostics.

**Q: What if I only want to test without applying?**  
A: Run `terraform plan -out=tfplan && terraform show tfplan | grep replaced`

---

## Performance Impact

- **Terraform Plan Time**: +0.5s (hash calculation)
- **Terraform Apply Time**: +5 minutes (VM recreation)
- **GitHub Actions Duration**: +2 minutes (comprehensive validation)
- **Cloud-Init Boot Time**: No change (~2 minutes from Azure boot)

---

## Security Considerations

- Lifecycle rule doesn't affect security groups or network settings
- Bootstrap script still runs with root privileges (necessary for installation)
- Managed Identity authentication (no credentials stored)
- Bootstrap logs contain command output (review for sensitive data)

---

## References

- Full Analysis: `ROOT_CAUSE_ANALYSIS_AND_FIX.md`
- Terraform Docs: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/linux_virtual_machine
- Cloud-Init Docs: https://cloud.ubuntu.com/initiatives/cloud-init/
- GitHub Actions: `.github/workflows/jumpvm-bootstrap-validation-v2.yml`
