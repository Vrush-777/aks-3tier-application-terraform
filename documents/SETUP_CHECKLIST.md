# Private AKS Deployment - Implementation Checklist

## Pre-Deployment Checklist

### 1. Jump VM Setup
- [ ] Jump VM created and running with system-assigned managed identity
- [ ] `kubectl` installed on Jump VM
- [ ] `helm` (v3.12+) installed on Jump VM
- [ ] `az` CLI installed on Jump VM
- [ ] Jump VM can authenticate to private AKS cluster (via managed identity + RBAC)
- [ ] Jump VM can pull from ACR (via AcrPull role)

### 2. RBAC Configuration
- [ ] System-assigned managed identity added to Jump VM resource
- [ ] `Azure Kubernetes Service Cluster User Role` assigned to VM identity on AKS cluster
- [ ] `Reader` role assigned to VM identity on resource group
- [ ] `AcrPull` role assigned to VM identity on ACR
- [ ] Verify role assignments:
  ```bash
  az role assignment list --assignee <JUMP_VM_PRINCIPAL_ID> --output table
  ```

### 3. GitHub Secrets Configuration
Add these secrets to your GitHub repository (Settings > Secrets > Actions):

- [ ] `AZURE_CREDENTIALS` — Service principal JSON (already exists)
  ```json
  {
    "clientId": "...",
    "clientSecret": "...",
    "subscriptionId": "...",
    "tenantId": "..."
  }
  ```

- [ ] `TF_VAR_SUBSCRIPTION_ID` — Azure subscription ID
  ```
  12345678-1234-1234-1234-123456789abc
  ```

- [ ] `TF_VAR_ACR_NAME` — Container registry name (without `.azurecr.io`)
  ```
  myacr
  ```

- [ ] `TF_VAR_AKS_CLUSTER_NAME` — AKS cluster name
  ```
  aks-dev
  ```

- [ ] `TF_VAR_RESOURCE_GROUP_NAME` — Resource group name
  ```
  rg-dev
  ```

- [ ] `TF_VAR_ENVIRONMENT_PREFIX` — Environment prefix (used to infer Jump VM name)
  ```
  dev
  ```

- [ ] `JUMP_VM_NAME` (Optional) — Jump VM name (if not set, defaults to `${TF_VAR_ENVIRONMENT_PREFIX}-jumpvm`)
  ```
  dev-jumpvm
  ```

### 4. Jump VM Deployment Script
- [ ] Create directory: `mkdir -p /opt/deploy`
- [ ] Create `/opt/deploy/deploy.sh` with deployment logic (see template in PRIVATE_AKS_DEPLOYMENT_GUIDE.md)
- [ ] Make script executable: `chmod +x /opt/deploy/deploy.sh`
- [ ] Test script locally on Jump VM:
  ```bash
  /opt/deploy/deploy.sh \
    --resource-group rg-dev \
    --cluster aks-dev \
    --tag test-sha-1234 \
    --registry myacr.azurecr.io
  ```

### 5. Workflow File
- [ ] Update `.github/workflows/deploy.yml` with new deploy job (done ✓)
  - [ ] Remove direct kubectl/helm commands
  - [ ] Add `az vm run-command invoke` step
  - [ ] Preserve Docker build/push steps
  - [ ] Add deployment status check step
  - [ ] Add deployment summary artifact step

### 6. Verification Steps

#### On Jump VM
```bash
# 1. Verify kubectl connectivity
kubectl cluster-info
kubectl get nodes

# 2. Verify helm access
helm repo list
helm list -A

# 3. Test deployment script
/opt/deploy/deploy.sh \
  --resource-group rg-dev \
  --cluster aks-dev \
  --tag test-1234 \
  --registry myacr.azurecr.io
```

#### In GitHub Actions
```bash
# 1. Verify Azure Login works
az account show

# 2. Verify Jump VM is reachable
az vm list -g rg-dev --query "[?name=='dev-jumpvm']"

# 3. Test vm run-command on a simple script
az vm run-command invoke \
  --resource-group rg-dev \
  --name dev-jumpvm \
  --command-id RunShellScript \
  --scripts "echo 'Hello from Jump VM'"
```

#### Full End-to-End Test
1. Merge a test branch to trigger the workflow
2. Monitor workflow execution in GitHub Actions
3. Check deployment artifacts in workflow run
4. Verify pods are running on AKS cluster:
   ```bash
   kubectl get pods -n employee-management
   ```

---

## Quick Reference Commands

### SSH into Jump VM
```bash
ssh azureuser@<JUMP_VM_PUBLIC_IP>
```

### View Jump VM Details
```bash
az vm show -g rg-dev -n dev-jumpvm --query "{name: name, id: id, identity: identity.principalId}"
```

### Check Jump VM Managed Identity
```bash
PRINCIPAL_ID=$(az vm show -g rg-dev -n dev-jumpvm --query identity.principalId -o tsv)
echo "Jump VM Principal ID: $PRINCIPAL_ID"
```

### Verify RBAC Role Assignments
```bash
PRINCIPAL_ID=$(az vm show -g rg-dev -n dev-jumpvm --query identity.principalId -o tsv)
az role assignment list --assignee $PRINCIPAL_ID --output table
```

### Test Azure VM Run Command
```bash
az vm run-command invoke \
  --resource-group rg-dev \
  --name dev-jumpvm \
  --command-id RunShellScript \
  --scripts "echo 'test' && whoami && pwd"
```

### View Workflow Run Logs
```bash
# GitHub UI
https://github.com/<OWNER>/<REPO>/actions

# Or via GitHub CLI
gh run view <RUN_ID> --log
```

---

## Troubleshooting Guide

| Issue | Cause | Solution |
|-------|-------|----------|
| `ResourceNotFound: Jump VM not found` | Jump VM name is incorrect or doesn't exist | Verify `JUMP_VM_NAME` secret or `TF_VAR_ENVIRONMENT_PREFIX` |
| `Authorization failed when creating role` | Service principal lacks `User Access Administrator` role | Add role to service principal in Azure |
| `Cannot get credentials: Private cluster AKS API` | AKS credentials not configured on Jump VM | Run `az aks get-credentials` on Jump VM from Jump VM |
| `helm: command not found` | Helm not installed on Jump VM | SSH to Jump VM and run `sudo apt-get install helm` |
| `kubectl: command not found` | kubectl not installed on Jump VM | SSH to Jump VM and install kubectl (included in `az aks install-cli`) |
| `timeout waiting for run-command` | Deployment script takes >1 hour | Optimize deployment or use SSH + nohup instead |
| `image pull errors` | ACR access denied | Verify AcrPull role on VM identity, test with `az acr login` |

---

## Security Best Practices

- [ ] **Principle of Least Privilege** — Use specific roles (AcrPull, Reader) instead of Contributor
- [ ] **Managed Identity** — Use system-assigned identity on Jump VM (no stored credentials)
- [ ] **Network Security** — Jump VM behind private network, SSH restricted by NSG
- [ ] **Audit Logging** — Enable audit logs for VM run commands:
  ```bash
  az monitor diagnostic-settings create \
    --resource /subscriptions/.../resourceGroups/rg-dev/providers/Microsoft.Compute/virtualMachines/dev-jumpvm \
    --name vm-diagnostics \
    --logs '[{"category": "RunCommandLogs", "enabled": true}]'
  ```
- [ ] **Secret Management** — Rotate `AZURE_CREDENTIALS` periodically
- [ ] **Workflow Permissions** — Grant GitHub Actions `contents: read` permission only

---

## Documentation Files

- **[PRIVATE_AKS_DEPLOYMENT_GUIDE.md](.github/PRIVATE_AKS_DEPLOYMENT_GUIDE.md)** — Full setup guide with example scripts
- **[WORKFLOW_CHANGES.md](.github/WORKFLOW_CHANGES.md)** — Detailed before/after workflow comparison
- **[terraform/JUMPVM_RBAC_SETUP.md](../terraform/JUMPVM_RBAC_SETUP.md)** — Terraform role assignment configuration
- **[.github/workflows/deploy.yml](.github/workflows/deploy.yml)** — Modified workflow file

---

## Next Steps

1. **Complete the checklist** above
2. **Configure GitHub secrets** (see section 3)
3. **Create `/opt/deploy/deploy.sh`** on Jump VM (use template from PRIVATE_AKS_DEPLOYMENT_GUIDE.md)
4. **Test locally** on Jump VM before running workflow
5. **Monitor first workflow run** in GitHub Actions
6. **Verify deployment** on AKS cluster
7. **Enable audit logging** for compliance

---

## Support & References

- [Azure VM Run Command Documentation](https://learn.microsoft.com/en-us/azure/virtual-machines/run-command)
- [Azure Kubernetes Service Cluster User Role](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#azure-kubernetes-service-cluster-user-role)
- [Helm Documentation](https://helm.sh/docs/)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
