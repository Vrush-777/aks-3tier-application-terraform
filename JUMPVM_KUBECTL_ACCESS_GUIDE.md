# Private AKS kubectl Access from Jump VM - Complete Guide

## Architecture Overview

```
┌─────────────────────────────────────────────────────┐
│                 Azure Subscription                   │
│                                                      │
│  ┌──────────────────────────────────────────────┐  │
│  │           VNet (Private)                     │  │
│  │                                              │  │
│  │  ┌──────────────────┐   ┌──────────────────┐ │  │
│  │  │   Jump VM        │   │   AKS Cluster    │ │  │
│  │  │                  │◄──►   (Private)      │ │  │
│  │  │  Azure CLI       │   │                  │ │  │
│  │  │  kubectl         │   │  ✅ Private API  │ │  │
│  │  │                  │   │  ✅ Entra RBAC   │ │  │
│  │  └──────────────────┘   │  ✅ No public IP │ │  │
│  │         │                └──────────────────┘ │  │
│  │         │                                     │  │
│  └─────────┼─────────────────────────────────────┘  │
│            │                                         │
│            ▼                                         │
│  ┌─────────────────────────────────────────────┐   │
│  │      Azure Entra ID (Authentication)        │   │
│  │  - User identity verification              │   │
│  │  - Group membership check                  │   │
│  │  - Cluster admin role assignment           │   │
│  └─────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────┘
```

## Prerequisites

### 1. Network Connectivity
- ✅ Jump VM in same VNet as AKS cluster
- ✅ Private DNS zone configured (or CoreDNS)
- ✅ NSG allows outbound to AKS API (port 6443)

### 2. Entra ID Configuration
- ✅ Create Entra ID admin group for AKS
- ✅ Add target users to admin group
- ✅ Record group Object ID

### 3. Terraform Configuration (Already Fixed)
- ✅ `local_account_disabled = true`
- ✅ `admin_group_object_ids = [<group-oid>]`
- ✅ Private cluster enabled
- ✅ No Azure RBAC role assignments

## Step-by-Step Access Instructions

### Step 1: SSH into Jump VM

```bash
# From local machine
ssh -i ~/.ssh/aks_key.pem azureuser@<jump-vm-public-ip>

# Or from bastion if Jump VM is private
az bastion ssh --name <bastion-name> \
  --resource-group <rg-name> \
  --target-resource-id <vm-resource-id>
```

### Step 2: Verify Azure CLI Installed

```bash
# Check if Azure CLI is installed (should be auto-installed by cloud-init)
az --version

# If not installed, install it:
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
```

### Step 3: Login to Azure with Entra ID

```bash
# Interactive login with Entra ID
az login --tenant <tenant-id>

# You'll see output like:
# The following tenants require multifactor authentication (mfa).
# Please use 'az login --tenant <tenant id>' to explicitly login to a tenant.
# Device Code: XXXXXXXXX
# Copy the code above and authenticate via: https://microsoft.com/devicelogin

# Browser will open automatically, or manually visit:
# https://microsoft.com/devicelogin
# Enter the device code
# Authenticate with your credentials
```

### Step 4: Verify Azure CLI Context

```bash
# Check logged-in account and subscription
az account show

# Output should show your user account and subscription
# {
#   "cloudName": "AzureCloud",
#   "homeTenantId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
#   "id": "yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy",
#   "isDefault": true,
#   "name": "YOUR_SUBSCRIPTION_NAME",
#   "tenantId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
#   "user": {
#     "cloudShellID": false,
#     "name": "user@company.com",
#     "type": "user"
#   }
# }
```

### Step 5: Get AKS Credentials

```bash
# Get credentials (will use Entra ID authentication)
az aks get-credentials \
  --resource-group aks-3tier-dev \
  --name <aks-cluster-name> \
  --overwrite-existing

# Output:
# Merged "aks-cluster-name" as current context in /home/azureuser/.kube/config
```

### Step 6: Verify kubectl Access

```bash
# List nodes (first kubectl command - may prompt for Entra ID auth)
kubectl get nodes

# Expected output:
# NAME                                STATUS   ROLES   AGE    VERSION
# aks-systempool-12345678-vmss000000   Ready    agent   15m    v1.28.0
# aks-systempool-12345678-vmss000001   Ready    agent   15m    v1.28.0
# aks-systempool-12345678-vmss000002   Ready    agent   15m    v1.28.0
```

### Step 7: Verify Admin Access

```bash
# Check if you're a cluster admin
kubectl auth can-i get nodes --as=system:authenticated

# Output:
# yes

# Check your current authorization rules
kubectl get clusterrolebindings -o wide

# Check group membership in cluster
kubectl get clusterrolebinding cluster-admin -o yaml | grep groups
```

## Entra ID Authentication Flow

### First Time kubectl Command (May Prompt for Auth)

```bash
$ kubectl get nodes

# If this is the first kubectl command, you may see:
# To sign in, use a web browser to open the page https://microsoft.com/devicelogin
# and enter the code XXXXXXXXX to authenticate.

# OR if using service principal:
# To sign in, use az login
# Trying to retrieve service principal from Azure CLI...
```

**What's happening:**
1. kubectl contacts private AKS API server (via VNet)
2. AKS API server requires Entra ID token
3. kubectl gets token from Azure CLI cache (if available) or prompts for auth
4. Azure Entra ID verifies the token
5. Entra ID checks if user is in `admin_group_object_ids`
6. If yes → cluster admin access
7. If no → authorization denied

### Subsequent kubectl Commands (No Auth Prompt)

```bash
# Token is cached for ~1 hour
kubectl get namespaces  # Uses cached token, no prompt
kubectl describe nodes   # Uses cached token, no prompt

# After token expires (~1 hour), next command will prompt again
```

### Clear Token Cache If Needed

```bash
# Clear the kubeconfig (removes cached credentials)
rm ~/.kube/config

# Next kubectl command will prompt for auth again
kubectl get nodes
```

## Common Scenarios

### Scenario 1: User is in Admin Group

```bash
# Expected behavior:
$ kubectl get nodes
NAME                                STATUS   ROLES   AGE    VERSION
aks-systempool-12345678-vmss000000   Ready    agent   15m    v1.28.0

# You can perform admin actions:
$ kubectl create namespace test
$ kubectl delete namespace test
$ kubectl get clusterroles
# (all succeed without RBAC errors)
```

### Scenario 2: User is NOT in Admin Group

```bash
# Expected behavior:
$ kubectl get nodes
error: You must be logged in to the server (Unauthorized)

# If user tries to check permissions:
$ kubectl auth can-i get nodes
no

# Solution: Add user to admin group in Entra ID or Azure Portal
```

### Scenario 3: Token Expired

```bash
# After ~1 hour of token inactivity
$ kubectl get nodes
# Your admin group membership is stale. Please try again or re-login.

# Solution: Logout and login again
$ az logout
$ az login
$ kubectl get nodes  # Now works with fresh token
```

### Scenario 4: Login to Different Subscription

```bash
# If you have access to multiple subscriptions
$ az account list

# Switch subscription
$ az account set --subscription <subscription-id>

# Get credentials for AKS in that subscription
$ az aks get-credentials --resource-group <rg> --name <cluster>

# Now kubectl points to the new cluster
$ kubectl get nodes
```

## Troubleshooting

### Issue: "Unable to connect to the server"

**Symptoms:**
```bash
$ kubectl get nodes
Unable to connect to the server: dial tcp [::1]:6443: connect: connection refused
```

**Causes & Solutions:**
1. kubectl configured for public endpoint instead of private
   ```bash
   # Check kubeconfig
   cat ~/.kube/config | grep server
   
   # Should show private FQDN like: https://aks-prod-cluster-12345678.privatelink.eastus.azmk8s.io:6443
   ```

2. Network connectivity issue from Jump VM to AKS
   ```bash
   # Test connectivity
   nslookup <aks-private-fqdn>  # Should resolve to private IP
   nc -zv <aks-private-ip> 6443  # Should show connection open
   ```

3. Private DNS not configured
   ```bash
   # Check DNS resolution
   nslookup aks-prod-cluster.privatelink.eastus.azmk8s.io
   
   # Should return private IP in VNet range (not public IP)
   ```

**Solution:**
```bash
# Re-get credentials with admin flag
az aks get-credentials \
  --resource-group aks-3tier-dev \
  --name <cluster-name> \
  --admin \
  --overwrite-existing
```

### Issue: "Unauthorized: Unauthorized" After Get-Credentials

**Symptoms:**
```bash
$ kubectl get nodes
error: You must be logged in to the server (Unauthorized)
```

**Causes & Solutions:**
1. User not in admin group
   ```bash
   # Check your Entra ID groups
   az ad user member-of list --upn <your-email>
   
   # Look for the AKS admin group
   # If not listed, ask administrator to add you
   ```

2. Stale or incorrect token
   ```bash
   # Clear kubeconfig and try again
   rm ~/.kube/config
   az logout
   az login
   az aks get-credentials --resource-group <rg> --name <cluster>
   kubectl get nodes
   ```

3. Multiple subscriptions causing confusion
   ```bash
   # Verify you're in the right subscription
   az account show | grep -i id
   
   # Compare with resource group subscription
   az group show --name <rg> --query id
   ```

### Issue: "Device Code" Not Appearing

**Symptoms:**
```bash
$ az login
# (hangs or doesn't show device code)
```

**Solution:**
```bash
# Use interactive login explicitly
az login --interactive

# Or with specific tenant
az login --tenant <tenant-id> --allow-no-subscriptions
```

### Issue: Private DNS Zone Not Resolving

**Symptoms:**
```bash
$ nslookup aks-prod-cluster.privatelink.eastus.azmk8s.io
Server: 127.0.0.53
Address: 127.0.0.53#53
** server can't find aks-prod-cluster.privatelink.eastus.azmk8s.io: NXDOMAIN
```

**Solution:**
Check Terraform output for private DNS zone configuration:
```bash
# From dev environment directory
terraform output aks_private_fqdn

# Private DNS zone should be linked to VNet
# Update /etc/resolv.conf or use Azure-provided DNS
echo "nameserver 168.63.129.16" | sudo tee -a /etc/resolv.conf
```

## Best Practices

### 1. Use Entra ID Groups (Not Individual Users)

```hcl
# ✅ CORRECT - Use groups
admin_group_object_ids = ["00000000-0000-0000-0000-000000000001"]

# ❌ AVOID - Direct user assignments create maintenance burden
```

### 2. Cache Credentials Securely

```bash
# Kubeconfig is stored in ~/.kube/config
# Restrict permissions for security
chmod 600 ~/.kube/config

# Consider storing credentials in Azure Key Vault for production
```

### 3. Use RBAC Roles for Non-Admin Access

```bash
# If user needs limited access, create RBAC role binding
# (Don't add everyone to admin group)

cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: viewer-role
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: view
subjects:
- kind: Group
  name: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"  # Viewer group object ID
  apiGroup: rbac.authorization.k8s.io
EOF
```

### 4. Rotate Access Regularly

```bash
# Clear cache and re-authenticate periodically
az logout
az login

# Re-get credentials
az aks get-credentials --resource-group <rg> --name <cluster> --overwrite-existing
```

### 5. Monitor Access Logs

```bash
# Check AKS audit logs in Azure Monitor
az monitor log-analytics query \
  --workspace <workspace-id> \
  --analytics-query 'AKSAudit | where ObjectRef.resource == "nodes" | take 10'
```

## Summary Checklist

- [ ] Network connectivity verified (VNet, DNS, NSG)
- [ ] User is member of Entra admin group
- [ ] Jump VM has Azure CLI installed
- [ ] `az login` successful with Entra ID
- [ ] `az aks get-credentials` completes without errors
- [ ] `kubectl get nodes` returns node list
- [ ] `kubectl auth can-i get nodes` returns "yes"
- [ ] Private FQDN in kubeconfig (not public)
- [ ] Token caching working (~1 hour validity)

---

## Technical Details

### Authentication Token Validity

- **Initial Token**: Valid for ~1 hour
- **Refresh**: Automatic when running kubectl commands
- **Manual Refresh**: `az login` command
- **Storage**: ~/.kube/config and ~/.azure/msal_token_cache.json

### Entra ID Group Sync

- **Initial Sync**: When AKS cluster created
- **Updates**: May take 5-10 minutes after group changes
- **Force Sync**: Can re-run `az aks get-credentials` to refresh

### Private DNS Zone

- **Auto-created**: By Terraform when private cluster enabled
- **Link**: Automatically linked to AKS VNet
- **Records**: Private A records for AKS API endpoints
- **Resolution**: Only works from within linked VNets

