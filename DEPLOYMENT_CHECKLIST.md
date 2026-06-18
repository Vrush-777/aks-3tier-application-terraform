# AKS Deployment Checklist & Validation Roadmap

## Pre-Deployment Validation

### 1. Terraform Configuration Check

- [ ] Run `terraform validate` in dev environment
  ```bash
  cd terraform/environments/dev
  terraform validate
  # Expected: Success! The configuration is valid.
  ```

- [ ] No undefined variable references
  ```bash
  terraform plan | grep -i "undefined\|error"
  # Expected: No output (no errors)
  ```

- [ ] No problematic azurerm_role_assignment
  ```bash
  grep -r "azurerm_role_assignment.*aks" terraform/modules/aks/
  # Expected: No output (resource removed)
  ```

### 2. Variable Definition Check

- [ ] `admin_group_object_ids` is defined
  ```bash
  grep -n "admin_group_object_ids" terraform/environments/dev/terraform.tfvars
  # Expected: Variable with at least one group object ID
  ```

- [ ] `aks_managed_identity_principal_id` is NOT referenced
  ```bash
  grep -r "aks_managed_identity_principal_id" terraform/modules/aks/
  # Expected: No output (variable removed)
  ```

- [ ] No orphaned variable references in module call
  ```bash
  grep -A 50 "module \"aks\"" terraform/environments/dev/main.tf | \
  grep -E "kubelet_role_assignment_id|aks_role_assignment_id|aks_managed_identity_principal_id"
  # Expected: No output (variables removed from module call)
  ```

### 3. Entra ID Admin Group Verification

- [ ] Admin group exists in Entra ID
  ```bash
  az ad group show --group <admin-group-object-id>
  # Expected: Returns group details
  ```

- [ ] Current user is member of admin group
  ```bash
  az ad group member check \
    --group <admin-group-object-id> \
    --member-id <your-user-object-id>
  # Expected: "true"
  ```

- [ ] Group object ID is correct format
  ```bash
  # Should be a UUID like: 00000000-0000-0000-0000-000000000000
  echo "<admin-group-object-id>" | grep -E "[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}"
  # Expected: Matches UUID pattern
  ```

### 4. Network Prerequisites

- [ ] VNet exists with AKS subnet
  ```bash
  az network vnet subnet show \
    --resource-group aks-3tier-dev \
    --vnet-name <vnet-name> \
    --name <aks-subnet-name>
  # Expected: Returns subnet details
  ```

- [ ] Jump VM subnet exists
  ```bash
  az network vnet subnet show \
    --resource-group aks-3tier-dev \
    --vnet-name <vnet-name> \
    --name <jumpvm-subnet-name>
  # Expected: Returns subnet details
  ```

- [ ] Application Gateway exists (for AGIC)
  ```bash
  az network application-gateway show \
    --resource-group aks-3tier-dev \
    --name <appgw-name>
  # Expected: Returns AppGW details
  ```

### 5. Managed Identities Verification

- [ ] AKS managed identity exists
  ```bash
  az identity show \
    --resource-group aks-3tier-dev \
    --name <aks-identity-name>
  # Expected: Returns identity details
  ```

- [ ] Kubelet managed identity exists
  ```bash
  az identity show \
    --resource-group aks-3tier-dev \
    --name <kubelet-identity-name>
  # Expected: Returns identity details
  ```

- [ ] AppGW managed identity exists
  ```bash
  az identity show \
    --resource-group aks-3tier-dev \
    --name <appgw-identity-name>
  # Expected: Returns identity details
  ```

---

## Deployment Phase

### Step 1: Terraform Plan

```bash
cd terraform/environments/dev

# Initialize (if needed)
terraform init

# Generate plan
terraform plan -out=tfplan

# Review plan output - check for:
# ✓ Resource creation count (should not be excessive)
# ✓ No variable errors
# ✓ Correct AKS configuration (private cluster, Entra RBAC)
# ✓ No azurerm_role_assignment resources for kubectl access
```

**Validation Checklist:**
- [ ] Plan completes without errors
- [ ] All resource references resolve correctly
- [ ] No undefined variable warnings
- [ ] AKS resource shows correct configuration:
  - `local_account_disabled = true`
  - `admin_group_object_ids = [<your-group-id>]`
  - Private DNS zone configured
  - AGIC enabled

### Step 2: Terraform Apply

```bash
# Apply the planned configuration
terraform apply tfplan

# Monitor for errors during apply
# Typical creation time: 15-20 minutes for AKS cluster

# Successful completion should show outputs:
# terraform output -json | jq '.'
```

**Validation Checklist:**
- [ ] Apply completes successfully (exit code 0)
- [ ] No resource creation failures
- [ ] Resource Group contains expected resources
- [ ] AKS cluster moves to "Running" state

### Step 3: Verify AKS Cluster Configuration

```bash
# Get cluster details
az aks show \
  --resource-group aks-3tier-dev \
  --name <cluster-name> \
  --query '{
    name: name,
    kubernetesVersion: kubernetesVersion,
    localAccountDisabled: disableLocalAccounts,
    privateFqdn: privateFqdn,
    aadProfile: aadProfile.adminGroupObjectIds,
    ingressProfile: ingressProfile
  }'

# Expected output:
# {
#   "name": "aks-prod-cluster",
#   "kubernetesVersion": "1.28.x",
#   "localAccountDisabled": true,
#   "privateFqdn": "aks-prod-cluster-12345678.privatelink.eastus.azmk8s.io",
#   "aadProfile": ["<your-admin-group-id>"],
#   "ingressProfile": {...}  # AGIC configuration
# }
```

**Validation Checklist:**
- [ ] `disableLocalAccounts` = true
- [ ] `privateFqdn` is not empty (private cluster working)
- [ ] `aadProfile.adminGroupObjectIds` contains your group ID
- [ ] `kubernetesVersion` matches expected version

### Step 4: Verify Private DNS Zone

```bash
# Get private DNS zone details
CLUSTER_NAME=$(terraform output -raw aks_name)
RESOURCE_GROUP=$(terraform output -raw resource_group_name)

az network private-dns zone list \
  --resource-group $RESOURCE_GROUP \
  --query "[?name == '${CLUSTER_NAME}.privatelink.eastus.azmk8s.io']"

# Expected: Returns private DNS zone details

# Verify DNS records
az network private-dns record-set a list \
  --resource-group $RESOURCE_GROUP \
  --zone-name "${CLUSTER_NAME}.privatelink.eastus.azmk8s.io"

# Expected: Returns A records for cluster endpoints
```

**Validation Checklist:**
- [ ] Private DNS zone exists
- [ ] Zone linked to AKS VNet
- [ ] A records created for cluster
- [ ] DNS resolution works from Jump VM subnet

---

## Post-Deployment: Jump VM Access Verification

### Step 1: SSH to Jump VM

```bash
# Get Jump VM public IP
JUMP_VM_IP=$(terraform output -raw jumpvm_public_ip 2>/dev/null || echo "not-output")

# SSH access
ssh -i <key-path> azureuser@$JUMP_VM_IP

# If using private Jump VM, use bastion
az bastion ssh \
  --name <bastion-name> \
  --resource-group aks-3tier-dev \
  --target-resource-id <vm-resource-id>
```

**Validation Checklist:**
- [ ] SSH connection successful
- [ ] Logged in as azureuser
- [ ] No permission denied errors

### Step 2: Verify Azure CLI

```bash
# Check Azure CLI version
az --version
# Expected: Azure CLI version >= 2.40.0

# Verify account
az account show
# Expected: Shows your subscription and user
```

**Validation Checklist:**
- [ ] Azure CLI installed
- [ ] Version is recent (>=2.40.0)
- [ ] Logged into correct subscription

### Step 3: Get AKS Credentials

```bash
# Get credentials from private AKS cluster
CLUSTER_NAME=$(az aks list --resource-group aks-3tier-dev --query "[0].name" -o tsv)
RG_NAME="aks-3tier-dev"

az aks get-credentials \
  --resource-group $RG_NAME \
  --name $CLUSTER_NAME \
  --overwrite-existing

# Expected output:
# Merged "<cluster-name>" as current context in /home/azureuser/.kube/config
```

**Validation Checklist:**
- [ ] Command completes without errors
- [ ] kubeconfig file created at ~/.kube/config
- [ ] Can read kubeconfig:
  ```bash
  cat ~/.kube/config | head -20
  ```

### Step 4: Verify kubectl Access

```bash
# List nodes
kubectl get nodes -o wide

# Expected output:
# NAME                                STATUS   ROLES   AGE    VERSION
# aks-systempool-12345678-vmss000000   Ready    agent   15m    v1.28.0
# aks-systempool-12345678-vmss000001   Ready    agent   15m    v1.28.0
# aks-systempool-12345678-vmss000002   Ready    agent   15m    v1.28.0
```

**Validation Checklist:**
- [ ] kubectl command succeeds (no "Unable to connect" error)
- [ ] All nodes show STATUS = Ready
- [ ] Node count matches deployment configuration

### Step 5: Verify Admin Access

```bash
# Check if you have cluster admin role
kubectl auth can-i get nodes
# Expected: yes

kubectl auth can-i delete clusterrolebindings
# Expected: yes

# Get cluster info
kubectl cluster-info

# List all namespaces
kubectl get namespaces

# Describe cluster admin role binding
kubectl get clusterrolebinding cluster-admin -o yaml | head -20
```

**Validation Checklist:**
- [ ] `kubectl auth can-i get nodes` returns "yes"
- [ ] `kubectl auth can-i delete clusterrolebindings` returns "yes"
- [ ] Can list namespaces and describe cluster
- [ ] Cluster admin role binding exists

### Step 6: Test Non-Admin Access (Optional)

```bash
# Try accessing as if you weren't admin (simulate)
# This should fail if local account is disabled

# Run a command that requires admin:
kubectl delete namespace default  # This SHOULD fail without admin

# Expected error:
# Error from server (Forbidden): namespaces "default" is forbidden: User "...@..." 
# cannot delete resource "namespaces" in API group "" in the namespace "default"
```

**Validation Checklist:**
- [ ] Unauthorized operations are blocked
- [ ] RBAC enforcement is working
- [ ] Only admin group users can perform admin actions

### Step 7: Verify Network Connectivity

```bash
# Test private DNS resolution
nslookup $(terraform output -raw aks_private_fqdn)
# Expected: Returns private IP (e.g., 10.x.x.x)

# Verify API server is accessible
curl -k https://$(terraform output -raw aks_private_fqdn):6443/version 2>/dev/null | grep gitVersion
# Expected: Shows Kubernetes version

# Check connection to ACR (if pods need to pull images)
az acr repository list --name <acr-name>
# Expected: Lists repositories
```

**Validation Checklist:**
- [ ] Private DNS resolves to private IP
- [ ] API server endpoint responds
- [ ] ACR access works
- [ ] Network path is private (no public IP)

---

## Post-Deployment: Container Deployment Verification

### Step 1: Create Test Deployment

```bash
# Create a simple test deployment
kubectl create deployment nginx-test --image=nginx:latest --replicas=3

# Verify deployment
kubectl get deployment nginx-test
kubectl get pods -l app=nginx-test

# Expected: 3 pods running
```

**Validation Checklist:**
- [ ] Deployment created successfully
- [ ] Pods are running (STATUS = Running)
- [ ] All replicas are ready

### Step 2: Verify Pod Networking

```bash
# Test communication between pods
POD_NAME=$(kubectl get pods -l app=nginx-test -o jsonpath='{.items[0].metadata.name}')

# Check pod IP
kubectl get pod $POD_NAME -o jsonpath='{.status.podIP}'
# Expected: IP in service CIDR range

# Test pod network
kubectl exec $POD_NAME -- ping -c 1 10.0.0.1
# Expected: Ping succeeds (or appropriate response)
```

**Validation Checklist:**
- [ ] Pods have IPs in service CIDR range
- [ ] Pod-to-pod networking works
- [ ] Network policy enforcement (if enabled)

### Step 3: Clean Up Test Resources

```bash
# Remove test deployment
kubectl delete deployment nginx-test

# Verify cleanup
kubectl get deployment
# Expected: nginx-test not listed
```

**Validation Checklist:**
- [ ] Deployment deleted
- [ ] Pods terminated
- [ ] Resources cleaned up

---

## Success Criteria Checklist

### Infrastructure
- [ ] AKS cluster deployed and running
- [ ] Private DNS zone created and linked
- [ ] Jump VM accessible via SSH
- [ ] Managed identities configured
- [ ] Application Gateway running
- [ ] Network connectivity verified

### Security
- [ ] Local accounts disabled (local_account_disabled = true)
- [ ] Entra ID RBAC enabled
- [ ] Admin group assigned to cluster
- [ ] RBAC enforcement working
- [ ] No public API endpoint
- [ ] Network policies configured

### Access Control
- [ ] Admin users can access cluster
- [ ] Non-admin users are denied
- [ ] kubectl works from Jump VM
- [ ] Private DNS resolution works
- [ ] Token-based authentication working
- [ ] Group membership enforced

### Cluster Functionality
- [ ] Nodes are healthy and ready
- [ ] All node pools running
- [ ] Pod networking functional
- [ ] AGIC ingress controller running
- [ ] Kubelet identity working
- [ ] ACR pull working

### Terraform
- [ ] Terraform validation succeeds
- [ ] No undefined variable errors
- [ ] Clean apply (no resource conflicts)
- [ ] Outputs generated correctly
- [ ] State file consistent

---

## Troubleshooting During Deployment

### Issue: Terraform Hangs During Apply

**Symptom:** 
```
module.aks.azurerm_kubernetes_cluster.aks: Still creating... [15m30s elapsed]
```

**Solution:**
1. Check for undefined variable references
   ```bash
   grep -r "var.aks_managed_identity_principal_id" terraform/modules/aks/
   grep -r "kubelet_role_assignment_id" terraform/modules/aks/
   ```

2. Revert to fixed version if still having issues
3. Run with increased verbosity:
   ```bash
   TF_LOG=DEBUG terraform apply tfplan 2>&1 | tee apply.log
   ```

### Issue: kubectl "Unable to Connect"

**Solution:**
1. Verify private DNS configuration
2. Check NSG rules allow AKS API (port 6443)
3. Re-get credentials:
   ```bash
   az aks get-credentials --resource-group <rg> --name <cluster> --overwrite-existing
   ```

### Issue: "Unauthorized" After Get-Credentials

**Solution:**
1. Verify user is in admin group:
   ```bash
   az ad group member check --group <group-id> --member-id <user-id>
   ```

2. Clear token cache:
   ```bash
   rm ~/.kube/config
   rm ~/.azure/msal_token_cache.json
   az logout && az login
   ```

---

## Documentation References

- ✅ [AKS_RBAC_FIX_SUMMARY.md](AKS_RBAC_FIX_SUMMARY.md) - Complete overview of fixes
- ✅ [AKS_IMPLEMENTATION_REFERENCE.md](AKS_IMPLEMENTATION_REFERENCE.md) - Detailed technical reference
- ✅ [JUMPVM_KUBECTL_ACCESS_GUIDE.md](JUMPVM_KUBECTL_ACCESS_GUIDE.md) - Step-by-step access guide
- ✅ [BEFORE_AFTER_COMPARISON.md](BEFORE_AFTER_COMPARISON.md) - What was changed

---

## Final Verification

After all steps complete, run this comprehensive check:

```bash
# From local machine (or Jump VM)
RESOURCE_GROUP="aks-3tier-dev"
CLUSTER_NAME="<your-cluster-name>"

# 1. Cluster status
az aks show --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME \
  --query "provisioningState" -o tsv
# Expected: "Succeeded"

# 2. Node status
kubectl get nodes --no-headers | wc -l
# Expected: >=3 (your node count)

# 3. Admin access
kubectl auth can-i '*' '*'
# Expected: "yes"

# 4. Local accounts disabled
az aks show --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME \
  --query "disableLocalAccounts" -o tsv
# Expected: "true"

echo "✅ All deployment verification checks passed!"
```

---

## Sign-Off

- [ ] All pre-deployment checks passed
- [ ] Terraform deployment successful
- [ ] Post-deployment verification complete
- [ ] Jump VM kubectl access confirmed
- [ ] Security requirements verified
- [ ] Documentation reviewed
- [ ] Team notified of deployment

**Deployment Status: ✅ PRODUCTION READY**

