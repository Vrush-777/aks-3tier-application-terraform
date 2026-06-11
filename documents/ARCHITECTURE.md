# Architecture & Best Practices

## 🏗️ Architecture Overview

### Network Topology

```
┌─────────────────────────────────────────────────────────────────────┐
│ Azure Subscription                                                  │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌────────────────────────────────────────────────────────────┐   │
│  │ Virtual Network (AKS-VNET)                                │   │
│  │                                                            │   │
│  │  ┌──────────────────────┐  ┌──────────────────────────┐  │   │
│  │  │ Application Gateway  │  │ Jump VM Subnet           │  │   │
│  │  │ Subnet (Public)      │  │ (Private)                │  │   │
│  │  │                      │  │ ┌────────────────────┐  │  │   │
│  │  │ - AppGW Instance     │  │ │ Jump VM            │  │  │   │
│  │  └──────────────────────┘  │ │ - System MI         │  │  │   │
│  │                             │ │ - az CLI            │  │  │   │
│  │  ┌──────────────────────┐   │ │ - kubectl           │  │  │   │
│  │  │ AKS Subnet           │   │ │ - kubelogin         │  │  │   │
│  │  │ (Private)            │   │ │ - Helm              │  │  │   │
│  │  │ ┌────────────────┐   │   │ │ - deploy.sh         │  │  │   │
│  │  │ │ Private Cluster│   │   │ └────────────────────┘  │  │   │
│  │  │ │ - No public API│   │   │         │               │  │   │
│  │  │ │ - Private DNS  │   │   │         │ (Helm Deploy) │  │   │
│  │  │ │ - System nodes │   │   │         ▼               │  │   │
│  │  │ │ - User nodes   │   │   │    ┌─────────────────┐  │  │   │
│  │  │ │ - Pods         │   │   │    │ Applications    │  │  │   │
│  │  │ │ - Services     │   │   │    │ - Backend (Java)│  │  │   │
│  │  │ │ - Ingress AGIC │───┼───┼────│ - Frontend      │  │  │   │
│  │  │ └────────────────┘   │   │    │ - PostgreSQL    │  │  │   │
│  │  └──────────────────────┘   │    └─────────────────┘  │  │   │
│  │                             └──────────────────────────┘  │   │
│  │  ┌──────────────────────┐                                │   │
│  │  │ PostgreSQL Subnet    │                                │   │
│  │  │ (Private)            │                                │   │
│  │  │ - PostgreSQL FS      │                                │   │
│  │  │ - Databases          │                                │   │
│  │  └──────────────────────┘                                │   │
│  │                                                            │   │
│  └────────────────────────────────────────────────────────────┘   │
│                                                                     │
│  ┌────────────────────────────────────────────────────────────┐   │
│  │ Azure Container Registry (ACR)                             │   │
│  │ - Backend images                                           │   │
│  │ - Frontend images                                          │   │
│  └────────────────────────────────────────────────────────────┘   │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              │
                    ┌─────────▼─────────┐
                    │ GitHub Actions    │
                    │ - Build jobs      │
                    │ - Push to ACR     │
                    │ - Invoke Run Cmd  │
                    └───────────────────┘
```

### Deployment Flow Sequence

```
GitHub Push
    ↓
GitHub Actions Workflow Triggered
    ↓
[Parallel Jobs]
├─ Build Backend → Docker Image → ACR
├─ Build Frontend → Docker Image → ACR
└─ Get Outputs (JUMP_VM_NAME, ACR_SERVER, etc.)
    ↓
Azure Login (Service Principal)
    ↓
az vm run-command invoke
    ├─ Target: Jump VM
    ├─ Command: /opt/deploy/deploy.sh
    └─ Script receives:
        - RESOURCE_GROUP
        - AKS_CLUSTER_NAME
        - IMAGE_TAG
        - ACR_LOGIN_SERVER
    ↓
On Jump VM:
    ├─ az login --identity (Managed Identity)
    ├─ az aks get-credentials
    ├─ kubelogin convert-kubeconfig
    ├─ kubectl verify connection
    ├─ helm upgrade --install
    └─ kubectl verify deployment
    ↓
Private AKS Cluster Updated
    ↓
Application Live
```

## 🔐 Security Architecture

### Identity & Access Control

```
┌─────────────────────────────────────────────────────────────┐
│ Jump VM - System Assigned Managed Identity                 │
│                                                             │
│  Identity Token (automatic, no credentials)                │
│    ├─ Microsoft Entra ID Provider                          │
│    ├─ Azure Metadata Service (169.254.169.254)             │
│    └─ Automatic token refresh                              │
│                                                             │
│  Role Assignments:                                          │
│    ├─ AKS Cluster User Role                                │
│    │   └─ Allows: kubectl auth, kubelogin                  │
│    ├─ Reader on Resource Group                             │
│    │   └─ Allows: Query AKS cluster metadata               │
│    └─ AcrPull on Container Registry                        │
│        └─ Allows: Pull images from ACR                     │
│                                                             │
└─────────────────────────────────────────────────────────────┘
        ↓
    GitHub Actions
    (Service Principal)
        ├─ Build images
        ├─ Push to ACR
        └─ Invoke VM Run Command

    Azure VM Run Command
        └─ Executes script on Jump VM
           using Jump VM's managed identity
```

### Network Security

```
┌─ Private AKS Cluster
│   ├─ No public API endpoint
│   ├─ Private DNS zone
│   ├─ Kubernetes API only accessible from VNet
│   └─ All pods in private subnets
│
├─ Jump VM
│   ├─ Public IP (for SSH only - can be removed)
│   ├─ Private IP in VNet
│   ├─ Access to private AKS API
│   └─ Access to ACR
│
├─ NSG Rules
│   ├─ Jump VM: Inbound SSH (22)
│   ├─ Jump VM: Outbound Internet (for az CLI, helm, etc.)
│   ├─ AKS Subnet: Inbound from Jump VM
│   ├─ AKS Subnet: Outbound to ACR
│   └─ PostgreSQL: Inbound from AKS only
│
└─ Application Gateway
    ├─ Public frontend
    ├─ Routes traffic to AKS Ingress
    └─ Private backend (via AGIC)
```

## 📊 Role-Based Access Control (RBAC)

### Roles and Permissions

```
┌─ GitHub Actions Runner
│  ├─ Service Principal
│  ├─ Can: Build, Push images, Invoke VM commands
│  └─ Permissions: Contributor on VM (AzureRM login)
│
├─ Jump VM (Managed Identity)
│  ├─ System Assigned Identity
│  ├─ Can: Authenticate to AKS, Query resources, Pull images
│  └─ Permissions:
│      ├─ Azure Kubernetes Service Cluster User
│      ├─ Reader (Resource Group)
│      └─ AcrPull (Container Registry)
│
└─ Human Developers
   ├─ SSH to Jump VM (if needed)
   ├─ Manually run deployment script
   └─ Troubleshooting & monitoring
```

## 🎯 Best Practices

### 1. Managed Identity Best Practices

✅ **DO**:
```hcl
# Use System-Assigned Identity (simpler)
identity {
  type = "SystemAssigned"
}

# Grant minimal required roles
role_definition_name = "Azure Kubernetes Service Cluster User Role"

# Use Azure CLI automatically with identity
az login --identity
```

❌ **DON'T**:
```hcl
# Don't use User-Assigned if System-Assigned works
identity {
  type           = "UserAssigned"
  identity_ids   = [...]
}

# Don't grant Contributor role
role_definition_name = "Contributor"

# Don't hardcode credentials
az login --username $user --password $pass
```

### 2. Terraform Best Practices

✅ **DO**:
```hcl
# Use locals for computed values
locals {
  JUMP_VM_NAME = "${var.prefix}-jumpvm"
}

# Use depends_on for clarity
depends_on = [module.aks, module.acr]

# Use outputs for integration
output "JUMP_VM_NAME" {
  value = azurerm_linux_virtual_machine.jumpvm.name
}
```

❌ **DON'T**:
```hcl
# Don't hardcode values
name = "jumpvm-prod-eastus"

# Don't rely on implicit dependencies
# Always specify depends_on

# Don't output sensitive data
output "vm_password" {
  value = random_password.vm.result
}
```

### 3. Cloud-Init Best Practices

✅ **DO**:
```yaml
packages:
  - curl
  - ca-certificates

runcmd:
  - apt-get update
  - apt-get install -y <package>
  - echo "Setup complete"

final_message: "Cloud-init completed"
```

❌ **DON'T**:
```yaml
# Don't run multiple installations sequentially
runcmd:
  - apt-get install package1
  - apt-get install package2  # Package order matters

# Don't ignore setup failures
runcmd:
  - command_that_might_fail  # No error handling

# Don't create unsecured scripts
runcmd:
  - echo "password123" > /opt/config.txt  # Security risk
```

### 4. GitHub Actions Best Practices

✅ **DO**:
```yaml
jobs:
  build:
    name: Build Backend
    runs-on: ubuntu-latest
    outputs:
      image-tag: ${{ steps.tag.outputs.tag }}
    steps:
      - uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}
```

❌ **DON'T**:
```yaml
# Don't commit credentials
env:
  ARM_CLIENT_ID: "hardcoded-value"

# Don't use hardcoded resource names
- run: az vm run-command invoke --name prod-vm-01

# Don't ignore job dependencies
jobs:
  deploy:
    # runs even if build fails
```

### 5. Security Best Practices

✅ **DO**:
```bash
# 1. Restrict Jump VM public access
# Allow SSH only from specific IPs
source_address_prefix = "203.0.113.0/24"

# 2. Use only required roles
"Azure Kubernetes Service Cluster User Role"
"Reader"
"AcrPull"

# 3. Rotate SSH keys regularly
# Regenerate and update GitHub Secrets quarterly

# 4. Monitor access logs
# Enable NSG flow logs
# Review authentication logs
```

❌ **DON'T**:
```bash
# 1. Don't expose to internet
source_address_prefix = "*"

# 2. Don't use broad roles
"Contributor"  # Too permissive

# 3. Don't leave credentials in logs
echo "Password: $PASSWORD"

# 4. Don't skip monitoring
# Disable logging/diagnostics
```

## 📈 Scaling Considerations

### Horizontal Scaling

```
Production Setup:
├─ Jump VM Auto-Scaling (not typical for Jump VM)
│  └─ Usually single instance (acts as gate)
│
├─ AKS Node Autoscaling
│  ├─ min_count: 3
│  ├─ max_count: 10
│  └─ Automatically scales based on pod requests
│
└─ Multiple Deployment Targets
   ├─ Dev AKS cluster
   ├─ Staging AKS cluster
   └─ Prod AKS cluster
       └─ Each with its own Jump VM
```

### Performance Optimization

```
1. Image Caching
   └─ GitHub Actions: cache Docker layers

2. Kubernetes Resources
   └─ Set requests/limits for pods
   └─ Enable HPA (Horizontal Pod Autoscaling)

3. Network Optimization
   └─ Use Azure CNI Overlay for reduced IP consumption
   └─ Configure load balancing properly

4. Storage
   └─ Use managed disks (default)
   └─ Configure Premium SSD for high-performance workloads
```

## 🔄 Disaster Recovery

### Backup Strategy

```
1. Infrastructure as Code
   └─ All Terraform code in Git (automatic backup)

2. Container Images
   └─ Stored in ACR (geo-replicated if Premium)
   └─ Multiple tags per image (latest, v1.0.0, etc.)

3. Application Configuration
   └─ Helm values in Git
   └─ ConfigMaps in Git or Helm

4. Data
   └─ PostgreSQL automated backups (30 days by default)
   └─ Configure geo-redundant storage (GRS)
```

### Recovery Procedures

```
To recover:
1. Redeploy infrastructure: terraform apply
2. Redeploy application: github trigger deployment workflow
3. Restore data: az postgres server restore --target-server <name>
```

## 📊 Monitoring & Observability

### Key Metrics to Monitor

```
Infrastructure:
├─ VM CPU/Memory usage
├─ Disk space
├─ Network throughput
└─ Identity token refresh rate

Application:
├─ Pod restart count
├─ Deployment status
├─ Service errors
└─ Request latency

Security:
├─ Failed authentication attempts
├─ Role assignment changes
├─ Image pull failures
└─ Network policy violations
```

### Logging Strategy

```
1. Azure Monitor
   └─ VM diagnostics
   └─ AKS cluster logs
   └─ ACR logs

2. Application Insights
   └─ Backend application logs
   └─ Request tracing
   └─ Performance metrics

3. Container Logs
   └─ kubectl logs
   └─ Pod events
   └─ Deployment status
```

## 🎓 Learning Resources

### Understanding Private AKS
- [Private AKS Clusters - Microsoft Learn](https://learn.microsoft.com/azure/aks/private-clusters)
- [kubelogin - Azure Authentication](https://github.com/Azure/kubelogin)
- [Managed Identities - Microsoft Learn](https://learn.microsoft.com/azure/active-directory/managed-identities-azure-resources/)

### Terraform Best Practices
- [Terraform AWS Best Practices](https://learn.hashicorp.com/terraform)
- [Module Composition Patterns](https://www.terraform.io/docs/language/modules/composition.html)

### GitHub Actions
- [GitHub Actions Documentation](https://docs.github.com/actions)
- [Azure Login Action](https://github.com/azure/login)

---

**This architecture ensures:**
✅ High security (no public API, managed identity)
✅ Automation (no manual VM setup)
✅ Scalability (AKS auto-scaling)
✅ Maintainability (IaC, GitOps patterns)
✅ Reliability (private networking, proper RBAC)
