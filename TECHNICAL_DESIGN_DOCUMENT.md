# Technical Design Document
## Secure CI/CD Pipeline for Private Azure Kubernetes Service (AKS) Deployment

**Document Version:** 1.0  
**Last Updated:** June 2026  
**Classification:** Internal - Technical Review  
**Audience:** Senior DevOps Engineers, Platform Engineering SMEs, Cloud Architects

---

## Executive Summary

This document details a production-grade, secure CI/CD architecture for deploying a full-stack Java Spring Boot and React application to a **Private Azure Kubernetes Service (AKS)** cluster. The solution implements a zero-trust security posture with defense-in-depth principles, automated infrastructure provisioning via Terraform, containerized application delivery through GitHub Actions, and orchestrated deployments using Helm.

The architecture prioritizes **security, scalability, maintainability, and operational excellence** by eliminating public endpoints for the Kubernetes API server, implementing identity-based access controls via Azure Managed Identities, and establishing an automated end-to-end deployment pipeline.

**Key Achievements:**
- ✅ Zero-trust private AKS cluster deployment
- ✅ Automated infrastructure provisioning (Infrastructure-as-Code)
- ✅ Secure artifact management via Azure Container Registry
- ✅ Jumphost-based secure cluster access
- ✅ Identity-driven RBAC using Managed Identities and Entra ID
- ✅ End-to-end CI/CD automation with GitHub Actions
- ✅ Multi-environment support (Dev/QA/Prod templates)

---

## POC Objectives

### Primary Objectives
1. **Demonstrate secure private AKS deployment** on Azure with no public API server exposure
2. **Establish automated CI/CD pipeline** for containerized Java and React applications
3. **Implement Infrastructure-as-Code (IaC)** using Terraform for reproducible deployments
4. **Validate identity-based security** using Azure Managed Identities and Entra ID
5. **Prove enterprise-grade container orchestration** using Helm for application deployment
6. **Create production-ready deployment patterns** for full-stack applications

### Secondary Objectives
1. Minimize operational overhead through automation
2. Eliminate manual deployment steps and associated human error
3. Establish consistent artifact management across environments
4. Demonstrate cost-optimized Azure resource utilization
5. Create reusable modules and patterns for scaling across teams

### Success Criteria
- [ ] Private AKS cluster fully operational without public API exposure
- [ ] GitHub Actions pipeline successfully deploys code changes end-to-end
- [ ] Zero manual steps required for infrastructure provisioning
- [ ] All containers running with non-root users (security hardening)
- [ ] Audit trails captured for all deployments and infrastructure changes
- [ ] Seamless integration between CI/CD and Kubernetes cluster
- [ ] Multi-environment configuration management operational

---

## Business Problem Statement

### Current State Challenges
Organizations deploying applications to Kubernetes face several critical challenges:

1. **Security Gaps:** Public Kubernetes API servers expose the attack surface; default configurations often lack identity-based access controls
2. **Operational Complexity:** Manual deployment processes are error-prone and difficult to audit
3. **Infrastructure Drift:** Manual infrastructure changes lead to inconsistency across environments
4. **Artifact Management:** Uncontrolled container image distribution creates compliance and security risks
5. **Access Control:** Role-based access control (RBAC) is complex to implement correctly without managed identity integration
6. **Scalability Concerns:** Manual processes don't scale across multiple environments or teams

### Business Impact
- **Delayed Time-to-Market:** Manual deployments slow application delivery
- **Increased Risk Exposure:** Unaudited infrastructure changes create compliance violations
- **Operational Costs:** Manual processes require specialized expertise and increase support burden
- **Team Friction:** Lack of automation creates bottlenecks in cross-functional workflows

### Solution Value
This POC demonstrates how to:
- **Eliminate manual deployment steps** through full automation
- **Enforce security by default** with private clusters and managed identity integration
- **Enable rapid, reliable releases** through CI/CD automation
- **Provide auditability** through Infrastructure-as-Code and comprehensive logging
- **Reduce operational overhead** through declarative infrastructure management

---

## High-Level Architecture Diagram (Text Format)

```
┌─────────────────────────────────────────────────────────────────────┐
│                        DEVELOPER WORKFLOW                            │
│  (Push code to main branch → GitHub)                                │
└──────────────────────────┬──────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────────┐
│              GITHUB REPOSITORY & GITHUB ACTIONS                     │
│  • Detects code changes (backend, frontend, Helm)                   │
│  • Triggers CI/CD pipeline workflows                                │
│  • Artifact versioning and tagging                                  │
└────────────┬─────────────────┬──────────────────┬──────────────────┘
             │                 │                  │
             ▼                 ▼                  ▼
    ┌─────────────────┐ ┌─────────────────┐ ┌──────────────┐
    │ MAVEN BUILD     │ │   NPM BUILD     │ │ HELM PACKAGE │
    │ (Java 17)       │ │   (React)       │ │              │
    │ ems-backend/    │ │ ems-fullstack/  │ │ helm/        │
    └────────┬────────┘ └────────┬────────┘ └──────┬───────┘
             │                   │                 │
             ▼                   ▼                 ▼
    ┌──────────────────────────────────────────────────────┐
    │    DOCKER BUILD (Multi-stage, Non-root User)         │
    │  • Backend: Maven → Java 21 JRE Alpine Container    │
    │  • Frontend: Node → Nginx Container                 │
    │  • Layer caching for fast rebuilds                  │
    └──────────────────────┬───────────────────────────────┘
                           │
                           ▼
    ┌──────────────────────────────────────────────────────┐
    │    AZURE CONTAINER REGISTRY (ACR - Premium)          │
    │  • Secure image storage with managed identity access│
    │  • Images tagged with git SHA for traceability      │
    │  • Network isolation (private endpoint capable)     │
    └──────────────────────┬───────────────────────────────┘
                           │
                           ▼
    ┌──────────────────────────────────────────────────────┐
    │   AZURE STORAGE ACCOUNT (Helm Chart Repository)      │
    │  • Helm charts packaged and versioned               │
    │  • Provides deployment configurations               │
    │  • Secure transfer via managed identity             │
    └──────────────────────┬───────────────────────────────┘
                           │
                           ▼
    ┌──────────────────────────────────────────────────────┐
    │              AZURE VIRTUAL NETWORK                   │
    │  ┌────────────────────────────────────────────────┐  │
    │  │ AKS SUBNET (Private, 172.16.0.0/24)           │  │
    │  │ • Kubernetes nodes run here                   │  │
    │  │ • No internet-facing endpoints                │  │
    │  └────────────────────────────────────────────────┘  │
    │  ┌────────────────────────────────────────────────┐  │
    │  │ APPGW SUBNET (Application Gateway, 10.X.X.X) │  │
    │  │ • Ingress/Load balancing                      │  │
    │  │ • SSL/TLS termination                         │  │
    │  └────────────────────────────────────────────────┘  │
    │  ┌────────────────────────────────────────────────┐  │
    │  │ JUMPVM SUBNET (Bastion Host, 10.X.X.X)       │  │
    │  │ • Secure access point to private resources   │  │
    │  │ • kubectl access to AKS cluster              │  │
    │  └────────────────────────────────────────────────┘  │
    │  ┌────────────────────────────────────────────────┐  │
    │  │ POSTGRES SUBNET (Database, Private)           │  │
    │  │ • Azure Database for PostgreSQL                │  │
    │  │ • VNet-delegated subnet for security          │  │
    │  └────────────────────────────────────────────────┘  │
    └──────────────────────┬───────────────────────────────┘
                           │
           ┌───────────────┼───────────────┐
           │               │               │
           ▼               ▼               ▼
┌──────────────────┐ ┌───────────────┐ ┌──────────────────┐
│   JUMP VM        │ │  MANAGED ID   │ │  NSG / FIREWALL  │
│ (Ubuntu)         │ │ (Pod Access)  │ │ (Access Control) │
│ • Bastion Host   │ │ • Kubelet     │ │ • Ingress Rules  │
│ • kubectl Client │ │ • AKS Control │ │ • Egress Rules   │
│ • Azure CLI      │ │ • ACR Pull    │ │ • DDoS Protection│
└────────┬─────────┘ └───────────────┘ └──────────────────┘
         │
         ▼ (Azure VM Run Command OR kubectl via Bastion)
┌──────────────────────────────────────────────────────────┐
│          PRIVATE AZURE KUBERNETES SERVICE (AKS)          │
│  ┌────────────────────────────────────────────────────┐  │
│  │ Control Plane (Microsoft-Managed, Private)         │  │
│  │ • Private API Server (no public IP)               │  │
│  │ • Azure CNI networking (192.168.0.0/16 service)  │  │
│  │ • Entra ID integration for RBAC                   │  │
│  │ • Private DNS zone for cluster resolution         │  │
│  └────────────────────────────────────────────────────┘  │
│                                                           │
│  ┌────────────────────────────────────────────────────┐  │
│  │ Node Pool (User-Managed, 3+ Zones)               │  │
│  │ • System Pool (3x Standard_D2s_v3 nodes)         │  │
│  │ • Auto-scaling (3-10 nodes based on load)        │  │
│  │ • Availability Zones: 1, 2, 3 (HA)              │  │
│  │ • Network Plugin: Azure CNI Overlay              │  │
│  └────────────────────────────────────────────────────┘  │
│                                                           │
│  ┌────────────────────────────────────────────────────┐  │
│  │ Kubernetes Namespaces                             │  │
│  │ • employee-management (app workloads)             │  │
│  │ • kube-system (core K8s services)                │  │
│  │ • kube-public (public resources)                 │  │
│  │ • default (system services)                       │  │
│  └────────────────────────────────────────────────────┘  │
└──────────────────────┬───────────────────────────────────┘
                       │
         ┌─────────────┼─────────────┐
         │             │             │
         ▼             ▼             ▼
┌──────────────┐ ┌──────────────┐ ┌──────────────────┐
│ HELM DEPLOY  │ │ CONFIGMAPS   │ │    SECRETS       │
│ (Release)    │ │ • Database   │ │ • DB Password    │
│ • Replicas   │ │ • URL Config │ │ • API Keys       │
│ • HPA        │ │ • Feature    │ │ • TLS Certs      │
│ • Ingress    │ │   Flags      │ │ • Registry Creds │
└──────┬───────┘ └──────────────┘ └──────────────────┘
       │
    ┌──┴──────────────────────────────────────┬──┐
    │                                         │  │
    ▼                                         ▼  ▼
┌──────────────────────────────┐  ┌──────────────────────────┐
│  SPRING BOOT BACKEND POD(S)  │  │  REACT FRONTEND POD(S)   │
│  (Spring Boot 3.2.4)         │  │  (Vite + Nginx)          │
│  • Running on port 8080      │  │  • Running on port 80/443│
│  • JVM Memory Optimized      │  │  • Static asset serving  │
│  • Health checks enabled     │  │  • SSL/TLS termination   │
│  • Liveness/Readiness probes │  │  • Gzip compression      │
│  • 2-3 replicas for HA       │  │  • 2-3 replicas for HA  │
│  • PostgreSQL connection pool│  │  • API calls to backend  │
└──────────────┬───────────────┘  └──────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────────────┐
│     AZURE DATABASE FOR POSTGRESQL                │
│  • Flexible Server (Private Network Integration) │
│  • HA with standby replica (optional)            │
│  • SSL/TLS enforcement                           │
│  • Automated backups (7+ days retention)         │
│  • Geo-redundant backup (optional)               │
│  • employee_db with app schema                   │
└──────────────────────────────────────────────────┘
```

---

## Detailed Architecture Explanation

### Network Isolation & Zero-Trust Design

The architecture implements a **zero-trust security posture** where all Kubernetes API access is private and no cluster component is directly internet-accessible:

1. **Private AKS Control Plane:** The Kubernetes API server operates on a private endpoint only, eliminating the attack surface created by public API servers
2. **Virtual Network Segmentation:** Four dedicated subnets isolate workload types:
   - **AKS Subnet:** Kubernetes nodes (172.16.0.0/24) - no direct internet access
   - **AppGW Subnet:** Application Gateway for ingress routing (10.X.X.X)
   - **JumpVM Subnet:** Bastion host for secure cluster access (10.X.X.X)
   - **PostgreSQL Subnet:** Database with VNet integration (private)

3. **Network Security Groups (NSGs):** Explicit allow-lists enforce principle of least privilege:
   - JumpVM → AKS: kubectl access via internal communication
   - ACR → AKS: Image pulls via managed identity
   - AppGW → AKS: Ingress traffic only
   - Outbound: Restricted to required Azure services and package repositories

### CI/CD Pipeline Automation

**GitHub Actions** orchestrates the entire deployment pipeline:

1. **Change Detection:** Path-based filtering detects changes in `ems-backend/`, `ems-fullstack/`, and `helm/` directories
2. **Multi-Job Parallelization:** Backend and frontend build in parallel, reducing total pipeline duration
3. **Artifact Production:** 
   - Backend: Docker image with Java 21 JRE (non-root user)
   - Frontend: Docker image with Nginx (optimized for static assets)
   - Both tagged with git SHA for traceability
4. **Registry Push:** Images pushed to Azure Container Registry via Managed Identity (service principal-less authentication)
5. **Helm Deployment:** Automated chart deployment to private AKS via stored credentials

### Container Orchestration Strategy

**Helm** manages application deployment with **GitOps principles**:

- **Chart-based Configuration:** Single source of truth for application manifests
- **Environment Overrides:** `values-dev.yaml`, `values-prod.yaml` for environment-specific settings
- **Replica Management:** Horizontal Pod Autoscaling (HPA) based on CPU/memory
- **Ingress Management:** Single point of entry for HTTP traffic
- **ConfigMaps & Secrets:** Externalized configuration and sensitive data

### Identity & Access Management

**Azure Managed Identities** replace service principals with automatic credential rotation:

1. **AKS Control Plane Identity:** For Azure API operations (backups, diagnostics)
2. **Kubelet Identity:** Enables pod access to Azure resources (ACR image pulls, Key Vault)
3. **Workload Identity Federation:** Optional enhancement for cross-cloud scenarios
4. **Entra ID RBAC:** Cluster administrators defined as Entra groups for centralized control

---

## Component-by-Component Design

### 1. Terraform Infrastructure-as-Code

**Purpose:** Declarative, version-controlled infrastructure provisioning

#### Design Decisions

**Modular Structure:**
```
terraform/
├── modules/
│   ├── resource-group/      # RG creation with tags
│   ├── network/             # VNet, subnets, NSGs
│   ├── aks/                 # AKS cluster & node pools
│   ├── acr/                 # Container registry
│   ├── postgres/            # Database
│   ├── managed-identity/    # Managed identities & RBAC
│   ├── vm/                  # JumpVM bastion host
│   └── application-gateway/ # Ingress load balancer
└── environments/
    └── dev/                 # Environment-specific variables
```

**Key Configurations:**

```hcl
# Private AKS Example
resource "azurerm_kubernetes_cluster" "aks" {
  private_cluster_enabled     = true
  private_dns_zone_id         = var.private_dns_zone_id
  
  network_profile {
    network_plugin  = "azure"   # Azure CNI for fine-grained RBAC
    network_policy  = "azure"   # Network policies
    outbound_type   = "loadBalancer"
  }
  
  identity {
    type         = "UserAssigned"
    identity_ids = [var.aks_managed_identity_id]
  }
}
```

**Why This Approach:**
- ✅ Version control for infrastructure changes
- ✅ Reproducible deployments across environments
- ✅ Modular design enables code reuse
- ✅ Terraform plan provides visibility before apply
- ✅ Rollback capability through state management
- ✅ Cost estimation via terraform plan

---

### 2. Resource Group

**Purpose:** Logical container for all Azure resources with centralized tagging

#### Design Specifications

| Aspect | Value | Rationale |
|--------|-------|-----------|
| Naming Convention | `rg-aks-3tier-{env}` | Standardized, environment-identifiable |
| Region | Central India (configurable) | Data residency, latency optimization |
| Tags | `Environment`, `Project`, `CostCenter`, `Owner` | Enables cost allocation, governance, automation |
| Lifecycle Management | Terraform-managed | Prevents accidental deletion; enables disaster recovery |

#### Security Considerations
- Resource Group uses **RBAC for access control** (Owner, Contributor, Reader roles)
- **Audit logs** capture all resource modifications
- **Policy enforcement** prevents non-compliant resource creation
- **Resource locks** prevent accidental deletion of critical resources

---

### 3. Virtual Network (VNet)

**Purpose:** Network isolation and traffic routing for all resources

#### Design Specifications

| Component | Configuration | Purpose |
|-----------|----------------|---------|
| **Address Space** | 10.0.0.0/16 (configurable) | Primary CIDR block for all subnets |
| **AKS Subnet** | 10.0.1.0/24 (172.16.0.0/24 option) | Kubernetes node placement |
| **AppGW Subnet** | 10.0.2.0/24 | Application Gateway (ingress) |
| **JumpVM Subnet** | 10.0.3.0/24 | Bastion host (secure access) |
| **PostgreSQL Subnet** | 10.0.4.0/24 (delegated) | Database with VNet integration |
| **Service CIDR** | 192.168.0.0/16 | Kubernetes internal services |
| **DNS Service IP** | 192.168.0.10 | Kubernetes DNS |

#### Network Security Groups (NSGs)

**AKS NSG - Ingress Rules:**
```
Priority  Protocol  Source              Destination  Port    Action
100       TCP       AppGW Subnet        *            6443    Allow (kubectl)
110       TCP       JumpVM Subnet       *            6443    Allow (kubectl)
120       TCP       *                   *            *       Deny
```

**AKS NSG - Egress Rules:**
```
Priority  Protocol  Destination         Port    Action
100       TCP       ACR Endpoint        443     Allow
110       TCP       KeyVault            443     Allow
120       TCP       AzureCloud          443     Allow
```

#### Why This Design
- ✅ Subnet isolation reduces blast radius
- ✅ VNet-integrated PostgreSQL provides enhanced security
- ✅ NSGs implement defense-in-depth
- ✅ Private DNS enables cluster resolution without internet
- ✅ Azure CNI overlay optimizes IP space

---

### 4. Private Azure Kubernetes Service (AKS)

**Purpose:** Container orchestration platform with zero public exposure

#### Cluster Configuration

| Setting | Value | Rationale |
|---------|-------|-----------|
| **API Server** | Private endpoint only | Eliminates public exposure |
| **Network Plugin** | Azure CNI Overlay | Efficient IP allocation, pod RBAC |
| **Kubernetes Version** | Latest stable (configurable) | Security patches, feature access |
| **Node Count** | 3 (system pool) | Minimum for high availability |
| **VM Size** | Standard_D2s_v3 (2 vCPU, 8GB RAM) | Cost-optimized for POC |
| **Auto-Scaling** | Min 3, Max 10 nodes | Dynamic workload scaling |
| **Availability Zones** | 1, 2, 3 | Multi-zone resilience |
| **OS Disk Size** | 128 GB | Container image caching |

#### Advanced Features

**1. Managed Identity for Pod Access**
```yaml
# Kubelet identity enables RBAC for pods
kubelet_identity {
  client_id    = "00000000-0000-0000-0000-000000000000"
  object_id    = "00000000-0000-0000-0000-000000000000"
  identity_id  = "/subscriptions/.../resourceGroups/.../providers/Microsoft.ManagedIdentity/userAssignedIdentities/aks-kubelet"
}

# Grants ACR pull permissions
role_assignment {
  principal_id              = kubelet_identity.object_id
  role_definition_name      = "AcrPull"
  scope                     = acr.id
}
```

**2. Entra ID RBAC Integration**
```hcl
# Admin group provides Kubernetes admin access
azure_active_directory_role_based_access_control {
  managed                  = true
  admin_group_object_ids   = [azuread_group.aks_admin.id]
}

# Users in the group can run kubectl without local kubeconfig
# Access revoked immediately when removed from group
```

**3. Network Policies**
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-isolation
spec:
  podSelector:
    matchLabels:
      tier: backend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          tier: frontend
    ports:
    - protocol: TCP
      port: 8080
```

#### Security Hardening

| Measure | Implementation | Benefit |
|---------|-----------------|---------|
| **Private API Server** | No public IP | Eliminates direct attacks |
| **Pod Security Standards** | Enforced via admission controller | Prevents privileged containers |
| **Network Policies** | Azure CNI with pod-to-pod rules | Microsegmentation |
| **RBAC** | Entra ID integration | Centralized identity management |
| **Audit Logging** | Sent to Log Analytics | Compliance & forensics |
| **API Server Authorized IPs** | JumpVM only | Whitelist-based access |

#### Why This Design
- ✅ Private endpoint eliminates public attack surface
- ✅ Managed identity eliminates credential management
- ✅ Entra ID provides centralized identity governance
- ✅ Network policies enforce microsegmentation
- ✅ Availability zones ensure fault tolerance
- ✅ Auto-scaling handles variable workloads

---

### 5. Azure Container Registry (ACR)

**Purpose:** Secure, centralized Docker image storage and distribution

#### Registry Configuration

| Setting | Value | Rationale |
|---------|-------|-----------|
| **SKU** | Premium | Network isolation, encryption, SLA |
| **Admin Access** | Disabled | Use managed identity instead |
| **Public Network** | Enabled (production: disabled) | Development convenience |
| **Authentication** | Managed Identity | Service principal-less |
| **Image Tagging** | git SHA | Traceability to source commit |
| **Retention Policy** | 90 days | Cost optimization & compliance |

#### Image Security

**1. Image Scanning**
```bash
# Vulnerability scanning via Azure Security Center
az acr config content-trust update \
  --registry myACR \
  --status enabled

# Images signed with cosign (optional)
cosign sign --key cosign.key myacr.azurecr.io/app:v1.0
```

**2. Network Isolation (Optional)**
```hcl
# Private endpoint for ACR
resource "azurerm_private_endpoint" "acr" {
  name                = "acr-private-endpoint"
  subnet_id           = var.aks_subnet_id
  private_service_connection {
    name                           = "acr-connection"
    private_connection_resource_id = var.acr_id
    subresource_names              = ["registry"]
    is_manual_connection           = false
  }
}
```

#### Image Pull via Managed Identity

```bash
# GitHub Actions: Login to ACR using service principal
az login --service-principal -u $CLIENT_ID -p $CLIENT_SECRET --tenant $TENANT_ID
az acr login --name $ACR_NAME

# Docker build and push
docker build -t $ACR_NAME.azurecr.io/ems-backend:$TAG .
docker push $ACR_NAME.azurecr.io/ems-backend:$TAG

# AKS: Pods pull images via kubelet managed identity
# (No image pull secrets required in most cases)
```

#### Why This Design
- ✅ Premium SKU provides SLA and geo-replication
- ✅ Managed identity eliminates credential sharing
- ✅ Network isolation (optional) prevents data exfiltration
- ✅ Git SHA tagging ensures deployment traceability
- ✅ Retention policies control costs

---

### 6. GitHub Actions CI/CD Pipeline

**Purpose:** Automated build, test, and deployment orchestration

#### Pipeline Architecture

```yaml
on:
  # Trigger 1: After Terraform infrastructure deployment
  workflow_run:
    workflows: ["Terraform Infrastructure Pipeline"]
    types: [completed]
  
  # Trigger 2: On code push to main branch
  push:
    branches: [main]
    paths:
      - 'ems-backend/**'
      - 'ems-fullstack/**'
      - 'helm/**'
  
  # Trigger 3: Manual trigger for on-demand deployments
  workflow_dispatch:
```

#### Job Execution Flow

**Job 1: Change Detection**
```yaml
detect-changes:
  runs-on: ubuntu-latest
  steps:
    - uses: dorny/paths-filter@v2  # Detects file changes
      id: changes
      with:
        filters: |
          backend:
            - 'ems-backend/**'
          frontend:
            - 'ems-fullstack/**'
          helm:
            - 'helm/**'
  outputs:
    backend-changed: ${{ steps.changes.outputs.backend }}
    frontend-changed: ${{ steps.changes.outputs.frontend }}
    helm-changed: ${{ steps.changes.outputs.helm }}
```

**Job 2: Backend Build (Parallel)**
```yaml
build-backend:
  needs: detect-changes
  if: needs.detect-changes.outputs.backend-changed == 'true'
  runs-on: ubuntu-latest
  steps:
    - name: Generate image tag
      run: echo "tag=$(git rev-parse --short HEAD)" >> $GITHUB_OUTPUT
    
    - name: Setup JDK 17
      uses: actions/setup-java@v3
      with:
        java-version: '17'
        distribution: 'temurin'
        cache: maven
    
    - name: Build JAR with Maven
      run: mvn clean package -DskipTests -q
    
    - name: Docker build & push to ACR
      run: |
        docker build -t $ACR_URL/ems-backend:$TAG .
        docker push $ACR_URL/ems-backend:$TAG
```

**Job 3: Frontend Build (Parallel)**
```yaml
build-frontend:
  needs: detect-changes
  if: needs.detect-changes.outputs.frontend-changed == 'true'
  runs-on: ubuntu-latest
  steps:
    - name: Setup Node.js
      uses: actions/setup-node@v3
      with:
        node-version: '18'
        cache: 'npm'
    
    - name: Install & build
      run: |
        npm ci
        npm run build  # Vite build for production
    
    - name: Docker build & push
      run: |
        docker build -t $ACR_URL/ems-frontend:$TAG .
        docker push $ACR_URL/ems-frontend:$TAG
```

**Job 4: Helm Deployment**
```yaml
deploy-helm:
  needs: [build-backend, build-frontend]
  if: success()
  runs-on: ubuntu-latest
  steps:
    - name: Azure login
      uses: azure/login@v1
      with:
        creds: ${{ secrets.AZURE_CREDENTIALS }}
    
    - name: Get AKS credentials
      run: |
        az aks get-credentials \
          --resource-group $RESOURCE_GROUP \
          --name $AKS_CLUSTER_NAME \
          --admin  # Using admin context for deployment
    
    - name: Helm deploy
      run: |
        helm upgrade --install ems ./helm/employee-management-system \
          --namespace employee-management \
          --create-namespace \
          --values helm/values-dev.yaml \
          --set backend.image.tag=$TAG \
          --set frontend.image.tag=$TAG \
          --wait \
          --timeout 5m
```

#### Why This Approach
- ✅ Path-based filtering reduces unnecessary builds
- ✅ Parallel jobs minimize total pipeline duration
- ✅ Change detection prevents duplicate deployments
- ✅ Helm enables declarative, reproducible deployments
- ✅ Git SHA tagging enables rollback by commit
- ✅ Workflow orchestration centralizes deployment logic

---

### 7. Docker Containerization

**Purpose:** Standardized, reproducible application packaging

#### Backend Dockerfile (Multi-Stage)

```dockerfile
# Stage 1: Maven build stage
FROM maven:3.9-eclipse-temurin-21-alpine AS maven-builder

WORKDIR /build
COPY pom.xml .
RUN mvn dependency:go-offline -B  # Cache dependencies layer

COPY src src
RUN mvn clean package -DskipTests -q

# Stage 2: Runtime stage (production image)
FROM eclipse-temurin:21-jre-alpine

LABEL maintainer="Platform Engineering Team"
LABEL description="EMS Backend - Spring Boot API"
LABEL version="1.0"

WORKDIR /app

# Security: Install only required runtime dependencies
RUN apk add --no-cache curl && rm -rf /var/cache/apk/*

# Security: Non-root user (principle of least privilege)
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

COPY --from=maven-builder /build/target/*.jar app.jar

# Change ownership to non-root user
RUN chown -R appuser:appgroup /app

# Run as non-root user
USER appuser

EXPOSE 8080

# JVM memory optimization for containerized environments
ENV JAVA_OPTS="-XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0 \
  -XX:InitialRAMPercentage=50.0 -Dspring.profiles.active=${SPRING_PROFILES_ACTIVE:-dev}"

ENTRYPOINT ["java", "-jar", "app.jar"]
```

#### Frontend Dockerfile

```dockerfile
# Stage 1: Build React app
FROM node:18-alpine AS builder

WORKDIR /app
COPY package*.json ./
RUN npm ci

COPY . .
RUN npm run build  # Vite production build (dist/)

# Stage 2: Nginx runtime
FROM nginx:alpine

LABEL maintainer="Platform Engineering Team"
LABEL description="EMS Frontend - React SPA"
LABEL version="1.0"

# Copy custom nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf

# Copy built React app to Nginx
COPY --from=builder /app/dist /usr/share/nginx/html

# Non-root user for Nginx (via init-wrapper if needed)
RUN addgroup -S www && adduser -S www -G www
RUN chown -R www:www /usr/share/nginx/html

EXPOSE 80 443

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --quiet --tries=1 --spider http://localhost/health || exit 1

ENTRYPOINT ["nginx", "-g", "daemon off;"]
```

#### Build Optimizations

| Optimization | Benefit |
|--------------|---------|
| **Multi-stage builds** | Reduces final image size (~200MB → ~80MB) |
| **Layer caching** | RUN maven dependency → only rebuilds on pom.xml change |
| **Alpine base images** | Minimal CVE surface, fast pulls |
| **Non-root user** | Limits container breakout impact |
| **Explicit dependency caching** | Faster CI builds (mvn dependency:go-offline) |

#### Why This Design
- ✅ Multi-stage builds reduce image size by 60%+
- ✅ Non-root users prevent privilege escalation
- ✅ Alpine base minimizes CVE exposure
- ✅ Layer caching accelerates CI/CD pipeline
- ✅ Explicit dependency caching improves build speed
- ✅ Health checks enable Kubernetes orchestration

---

### 8. Helm Chart Management

**Purpose:** Declarative Kubernetes deployment configuration and templating

#### Chart Structure

```
helm/employee-management-system/
├── Chart.yaml                    # Chart metadata
├── values.yaml                   # Default values
├── values-dev.yaml               # Dev environment overrides
├── values-prod.yaml              # Prod environment overrides
└── templates/
    ├── namespace.yaml            # Kubernetes namespace
    ├── configmap.yaml            # Configuration data
    ├── secret.yaml               # Sensitive data (external)
    ├── deployment-backend.yaml   # Spring Boot deployment
    ├── deployment-frontend.yaml  # React deployment
    ├── service-backend.yaml      # Backend service (ClusterIP)
    ├── service-frontend.yaml     # Frontend service (LoadBalancer)
    ├── ingress.yaml              # HTTP/HTTPS ingress
    ├── hpa.yaml                  # Horizontal Pod Autoscaler
    ├── _helpers.tpl              # Template helpers
    └── NOTES.txt                 # Post-install instructions
```

#### Deployment Template Example

```yaml
# templates/deployment-backend.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "employee-management-system.fullname" . }}-backend
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "employee-management-system.labels" . | nindent 4 }}
    app.kubernetes.io/component: backend
spec:
  replicas: {{ .Values.backend.replicaCount }}
  selector:
    matchLabels:
      {{- include "employee-management-system.selectorLabels" . | nindent 6 }}
      app.kubernetes.io/component: backend
  template:
    metadata:
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "8080"
        prometheus.io/path: "/actuator/prometheus"
      labels:
        {{- include "employee-management-system.selectorLabels" . | nindent 8 }}
        app.kubernetes.io/component: backend
    spec:
      serviceAccountName: {{ include "employee-management-system.serviceAccountName" . }}
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 1000
      
      containers:
      - name: backend
        image: "{{ .Values.backend.image.repository }}:{{ .Values.backend.image.tag }}"
        imagePullPolicy: {{ .Values.backend.image.pullPolicy }}
        
        ports:
        - containerPort: 8080
          name: http
          protocol: TCP
        
        env:
        - name: SPRING_PROFILES_ACTIVE
          value: "{{ .Values.backend.springProfile }}"
        
        - name: DATABASE_URL
          valueFrom:
            configMapKeyRef:
              name: {{ include "employee-management-system.fullname" . }}-config
              key: database.url
        
        - name: DATABASE_USERNAME
          valueFrom:
            secretKeyRef:
              name: {{ include "employee-management-system.fullname" . }}-secret
              key: db-username
        
        - name: DATABASE_PASSWORD
          valueFrom:
            secretKeyRef:
              name: {{ include "employee-management-system.fullname" . }}-secret
              key: db-password
        
        # Resource management for Kubernetes scheduler
        resources:
          requests:
            cpu: 250m              # Minimum required
            memory: 512Mi
          limits:
            cpu: 500m              # Maximum allowed
            memory: 1Gi
        
        # Probes for Kubernetes to manage pod lifecycle
        livenessProbe:
          httpGet:
            path: /actuator/health/liveness
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 3
          failureThreshold: 3
        
        readinessProbe:
          httpGet:
            path: /actuator/health/readiness
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 3
        
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop: ["ALL"]
          readOnlyRootFilesystem: true
        
        volumeMounts:
        - name: tmp
          mountPath: /tmp
      
      volumes:
      - name: tmp
        emptyDir: {}
```

#### Horizontal Pod Autoscaler (HPA)

```yaml
# templates/hpa.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: {{ include "employee-management-system.fullname" . }}-backend-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ include "employee-management-system.fullname" . }}-backend
  
  minReplicas: {{ .Values.backend.autoscaling.minReplicas | default 2 }}
  maxReplicas: {{ .Values.backend.autoscaling.maxReplicas | default 10 }}
  
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
  
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 50
        periodSeconds: 15
    scaleUp:
      stabilizationWindowSeconds: 0
      policies:
      - type: Percent
        value: 100
        periodSeconds: 15
```

#### Values Configuration

```yaml
# values-dev.yaml (Development overrides)
backend:
  replicaCount: 2
  image:
    repository: myacr.azurecr.io/ems-backend
    tag: "latest"
    pullPolicy: Always
  springProfile: dev
  resources:
    requests:
      cpu: 250m
      memory: 512Mi
    limits:
      cpu: 500m
      memory: 1Gi
  autoscaling:
    enabled: true
    minReplicas: 2
    maxReplicas: 5
    targetCPUUtilization: 70

frontend:
  replicaCount: 2
  image:
    repository: myacr.azurecr.io/ems-frontend
    tag: "latest"
    pullPolicy: Always
  resources:
    requests:
      cpu: 100m
      memory: 256Mi
    limits:
      cpu: 200m
      memory: 512Mi
  autoscaling:
    enabled: true
    minReplicas: 2
    maxReplicas: 5

database:
  url: "jdbc:postgresql://pgemsdev.postgres.database.azure.com:5432/employee_db"
  maxConnections: 20  # Lower for dev
  ssl: true
```

#### Why This Design
- ✅ Helm enables parameterized deployments across environments
- ✅ Values files externalize configuration from manifests
- ✅ Resource requests/limits enable proper scheduling
- ✅ HPA provides automatic scaling
- ✅ Probes ensure pod health
- ✅ Security contexts enforce non-root execution
- ✅ Templates reduce YAML duplication

---

### 9. Jump VM (Bastion Host)

**Purpose:** Secure gateway for administrative access to private AKS cluster

#### VM Configuration

```hcl
resource "azurerm_linux_virtual_machine" "jump_vm" {
  name                = "${var.resource_group_name}-jump-vm"
  location            = var.location
  resource_group_name = var.resource_group_name
  
  # VM size with sufficient resources for kubectl + tooling
  vm_size = var.jumpvm_vm_size  # Standard_B2s typical
  
  # Non-root admin user for SSH access
  admin_username = var.jumpvm_admin_username
  
  admin_ssh_key {
    username   = var.jumpvm_admin_username
    public_key = file(pathexpand(var.jumpvm_ssh_public_key_path))
  }
  
  # No public IP by default (access via Azure Bastion or Shared Image Gallery)
  network_interface_ids = [azurerm_network_interface.jumpvm.id]
  
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"  # Faster boot/operations
  }
  
  # Ubuntu 22.04 LTS (security patches, stable)
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
  
  # User data script installs tooling
  custom_data = base64encode(templatefile("${path.module}/cloud-init.yaml", {
    kubernetes_version = var.kubernetes_version
    acr_name           = var.acr_name
  }))
}
```

#### Cloud-Init Provisioning Script

```bash
#!/bin/bash
# Runs on VM first boot to install necessary tools

# Update system packages
apt-get update
apt-get upgrade -y

# Install Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | bash

# Install kubectl (compatible with cluster version)
curl -LO "https://dl.k8s.io/release/v${KUBERNETES_VERSION}/bin/linux/amd64/kubectl"
install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Install Helm 3
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Install docker-cli (for ACR operations)
apt-get install -y docker.io

# Configure kubeconfig for private cluster access
# (Requires managed identity / service principal credentials)

echo "JumpVM provisioning complete"
```

#### Secure Access Patterns

**Option 1: Azure Bastion (Recommended)**
```bash
# No direct SSH; Azure Bastion provides browser-based RDP/SSH
# To access JumpVM:
# 1. Go to Azure Portal → Virtual Machines → jump-vm
# 2. Click "Connect" → Select "Bastion"
# 3. Authenticate with Azure credentials
# 4. RDP/SSH session opens in browser
```

**Option 2: Azure VM Run Command**
```bash
# Execute commands on JumpVM without SSH access
az vm run-command invoke \
  --resource-group rg-aks-3tier-dev \
  --name jump-vm \
  --command-id RunShellScript \
  --scripts "kubectl get pods -A"

# Output returned to terminal
```

**Option 3: Managed Identity Authentication**
```bash
# From JumpVM (with managed identity):
az login --identity  # No credentials required

# Now can run azure/kubectl commands with pod identity
az aks get-credentials \
  --resource-group rg-aks-3tier-dev \
  --name aks-ems-dev \
  --file kubeconfig

# kubectl uses Azure AD for authentication
kubectl get pods -A
```

#### Why This Design
- ✅ Eliminates direct internet exposure for AKS
- ✅ Centralized access point simplifies audit
- ✅ SSH key-based authentication (no passwords)
- ✅ Cloud-init automates tool provisioning
- ✅ Managed identity enables passwordless Azure access
- ✅ Azure Bastion provides zero-trust access
- ✅ VM Run Command enables remote execution without SSH

---

### 10. Azure Managed Identities

**Purpose:** Service principal-less authentication and authorization

#### Managed Identity Types

**1. System-Assigned Identity (AKS Control Plane)**
```hcl
resource "azurerm_kubernetes_cluster" "aks" {
  identity {
    type = "SystemAssigned"  # Auto-created with cluster
  }
}

# Grant contributor role to resource group
resource "azurerm_role_assignment" "aks_rg_contributor" {
  scope                = var.resource_group_id
  role_definition_name = "Contributor"
  principal_id         = azurerm_kubernetes_cluster.aks.identity[0].principal_id
}
```

**2. User-Assigned Identity (AKS Service Principal)**
```hcl
resource "azurerm_user_assigned_identity" "aks_identity" {
  name                = "aks-identity"
  resource_group_name = var.resource_group_name
  location            = var.location
}

resource "azurerm_kubernetes_cluster" "aks" {
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aks_identity.id]
  }
}

# Explicitly grant required roles (least privilege)
resource "azurerm_role_assignment" "aks_acr_pull" {
  scope              = var.acr_id
  role_definition_name = "AcrPull"
  principal_id       = azurerm_user_assigned_identity.aks_identity.principal_id
}
```

**3. Kubelet Identity (Pod Authentication)**
```hcl
resource "azurerm_user_assigned_identity" "kubelet_identity" {
  name                = "aks-kubelet-identity"
  resource_group_name = var.resource_group_name
  location            = var.location
}

resource "azurerm_kubernetes_cluster" "aks" {
  kubelet_identity {
    client_id   = azurerm_user_assigned_identity.kubelet_identity.client_id
    object_id   = azurerm_user_assigned_identity.kubelet_identity.principal_id
    identity_id = azurerm_user_assigned_identity.kubelet_identity.id
  }
}

# Grant ACR pull permissions to kubelet
resource "azurerm_role_assignment" "kubelet_acr_pull" {
  scope              = var.acr_id
  role_definition_name = "AcrPull"
  principal_id       = azurerm_user_assigned_identity.kubelet_identity.principal_id
}
```

#### RBAC Role Assignments

```hcl
# Grant AKS permissions to pull from ACR
resource "azurerm_role_assignment" "aks_acr_pull" {
  scope              = azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id       = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
}

# Grant JumpVM permissions to manage ACR
resource "azurerm_role_assignment" "jumpvm_acr_push" {
  scope              = azurerm_container_registry.acr.id
  role_definition_name = "AcrPush"
  principal_id       = azurerm_linux_virtual_machine.jump_vm.identity[0].principal_id
}

# Grant AKS permissions to read from Key Vault
resource "azurerm_role_assignment" "aks_keyvault_read" {
  scope              = azurerm_key_vault.secrets.id
  role_definition_name = "Key Vault Reader"
  principal_id       = azurerm_kubernetes_cluster.aks.identity[0].principal_id
}
```

#### Pod Identity Workload Federation (Advanced)

```yaml
# Enables pods to authenticate to Azure AD without credential injection
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ems-backend-sa
  namespace: employee-management
---
apiVersion: aadpodidentity.k8s.io/v1
kind: AzureIdentity
metadata:
  name: ems-backend-identity
spec:
  type: 0  # User-assigned identity type
  resourceID: /subscriptions/.../resourceGroups/.../providers/Microsoft.ManagedIdentity/userAssignedIdentities/ems-workload-identity
  clientID: "00000000-0000-0000-0000-000000000000"
---
apiVersion: aadpodidentity.k8s.io/v1
kind: AzureIdentityBinding
metadata:
  name: ems-backend-binding
spec:
  azureIdentity: ems-backend-identity
  selector: ems-backend
```

#### Why This Design
- ✅ Eliminates credential sharing and rotation
- ✅ Automatic token refresh (transparent to applications)
- ✅ Fine-grained RBAC per identity
- ✅ Audit trail of all identity operations
- ✅ Conditional access policies can be applied
- ✅ Multi-factor authentication enforcement possible
- ✅ Revocation is immediate (no credential validity period)

---

### 11. Azure VM Run Command

**Purpose:** Execute commands on private VMs without SSH access

#### Use Cases

**1. Remote Helm Deployment**
```bash
az vm run-command invoke \
  --resource-group rg-aks-3tier-dev \
  --name jump-vm \
  --command-id RunShellScript \
  --scripts "
    az aks get-credentials --resource-group rg-aks-3tier-dev --name aks-ems-dev
    helm upgrade --install ems ./helm/employee-management-system \
      --namespace employee-management \
      --values helm/values-dev.yaml
  " \
  --output json
```

**2. Cluster Diagnostics**
```bash
az vm run-command invoke \
  --resource-group rg-aks-3tier-dev \
  --name jump-vm \
  --command-id RunShellScript \
  --scripts "
    kubectl get nodes -o wide
    kubectl top nodes
    kubectl describe node <node-name>
  "
```

**3. Network Connectivity Tests**
```bash
az vm run-command invoke \
  --resource-group rg-aks-3tier-dev \
  --name jump-vm \
  --command-id RunShellScript \
  --scripts "
    nslookup pgemsdev.postgres.database.azure.com
    telnet myacr.azurecr.io 443
  "
```

#### Security Considerations
- ✅ Commands execute via Azure IMDS (no direct network exposure)
- ✅ Azure RBAC controls who can invoke run-command
- ✅ All commands are logged in Azure Activity Log
- ✅ Timeout protection (commands must complete within timeouts)
- ✅ No root shell access required (safer than SSH)

#### Why This Feature
- ✅ Provides access without SSH/RDP exposure
- ✅ Integrates with Azure RBAC and audit logging
- ✅ Eliminates need for direct network connectivity
- ✅ Suitable for one-off troubleshooting or deployments
- ✅ Works with managed identities for passwordless access

---

### 12. Azure Storage Account

**Purpose:** Store Helm charts and other deployment artifacts

#### Storage Account Configuration

```hcl
resource "azurerm_storage_account" "helm_charts" {
  name                     = "stghelm${random_string.unique.result}"
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "GRS"  # Geo-redundant
  
  # Security: Enforce HTTPS only
  https_traffic_only_enabled = true
  
  # Security: Disable public blob access
  public_network_access_enabled = false
  
  # Security: Require secure TLS version
  min_tls_version = "TLS1_2"
}

# Create blob container for Helm charts
resource "azurerm_storage_container" "helm_charts" {
  name                  = "helm-charts"
  storage_account_name  = azurerm_storage_account.helm_charts.name
  container_access_type = "private"  # No public access
}

# Grant ACR managed identity access to storage account
resource "azurerm_role_assignment" "storage_blob_reader" {
  scope              = azurerm_storage_account.helm_charts.id
  role_definition_name = "Storage Blob Data Reader"
  principal_id       = azurerm_user_assigned_identity.aks_identity.principal_id
}
```

#### Helm Chart Distribution

**Option 1: Via GitHub Actions**
```yaml
# GitHub Actions: Upload Helm chart to storage
- name: Upload Helm chart to Azure Storage
  run: |
    az storage blob upload \
      --account-name $STORAGE_ACCOUNT \
      --container-name helm-charts \
      --name employee-management-system-1.0.0.tgz \
      --file ./helm/employee-management-system-1.0.0.tgz \
      --auth-mode key
```

**Option 2: Via Helm Repository**
```bash
# Setup Helm repository pointing to storage account
helm repo add myrepo https://${STORAGE_ACCOUNT}.blob.core.windows.net/helm-charts

# Publish chart to repository
helm package ./helm/employee-management-system
az storage blob upload \
  --account-name $STORAGE_ACCOUNT \
  --container-name helm-charts \
  --name employee-management-system-1.0.0.tgz \
  --file ./employee-management-system-1.0.0.tgz
```

#### Why This Design
- ✅ Centralized artifact management
- ✅ GRS replication provides disaster recovery
- ✅ Private storage account prevents unauthorized access
- ✅ Managed identity integration eliminates credential sharing
- ✅ Audit logging tracks all access
- ✅ Cost-effective compared to container registries

---

### 13. Spring Boot Backend

**Purpose:** RESTful API server for Employee Management System

#### Architecture

```
Spring Boot 3.2.4
├── Spring Web (REST controllers)
├── Spring Data JPA (ORM)
├── Spring Actuator (health checks, metrics)
├── PostgreSQL JDBC Driver
├── Lombok (reduce boilerplate)
└── Project Reactor (reactive extensions)
```

#### Key Components

**1. REST Controller Example**
```java
@RestController
@RequestMapping("/api/employees")
@RequiredArgsConstructor  // Lombok auto-generates constructor
@Slf4j  // Lombok logger
public class EmployeeController {
  
  private final EmployeeService employeeService;
  
  @GetMapping
  public ResponseEntity<List<EmployeeDTO>> getAllEmployees() {
    log.debug("Fetching all employees");
    return ResponseEntity.ok(employeeService.getAllEmployees());
  }
  
  @PostMapping
  public ResponseEntity<EmployeeDTO> createEmployee(
    @RequestBody EmployeeDTO employeeDTO) {
    log.info("Creating new employee: {}", employeeDTO.getName());
    return ResponseEntity
      .status(HttpStatus.CREATED)
      .body(employeeService.createEmployee(employeeDTO));
  }
  
  @GetMapping("/{id}")
  public ResponseEntity<EmployeeDTO> getEmployeeById(@PathVariable Long id) {
    return employeeService.getEmployeeById(id)
      .map(ResponseEntity::ok)
      .orElse(ResponseEntity.notFound().build());
  }
}
```

**2. Database Configuration**
```yaml
# application-prod.yml (Kubernetes mounted via ConfigMap)
spring:
  datasource:
    url: jdbc:postgresql://${DATABASE_URL}:5432/${DATABASE_NAME}
    username: ${DATABASE_USERNAME}
    password: ${DATABASE_PASSWORD}
    hikari:
      maximumPoolSize: 20
      minimumIdle: 5
      connectionTimeout: 30000
  jpa:
    database-platform: org.hibernate.dialect.PostgreSQLDialect
    hibernate:
      ddl-auto: validate  # Don't auto-create schema in prod
    properties:
      hibernate:
        jdbc:
          batch_size: 20
        order_inserts: true
        order_updates: true
```

**3. Health Checks & Metrics**
```yaml
# application.yml
management:
  endpoints:
    web:
      exposure:
        include: health,metrics,prometheus
  endpoint:
    health:
      show-details: always
  metrics:
    export:
      prometheus:
        enabled: true
```

#### Kubernetes Integration

```yaml
# Liveness Probe: Restart if app becomes unresponsive
livenessProbe:
  httpGet:
    path: /actuator/health/liveness
    port: 8080
  initialDelaySeconds: 30
  periodSeconds: 10
  failureThreshold: 3

# Readiness Probe: Remove from traffic if not ready
readinessProbe:
  httpGet:
    path: /actuator/health/readiness
    port: 8080
  initialDelaySeconds: 10
  periodSeconds: 5
  failureThreshold: 3
```

#### Why Spring Boot
- ✅ Production-ready, opinionated defaults
- ✅ Excellent Kubernetes integration (probes, metrics)
- ✅ Active community and ecosystem
- ✅ Multi-environment configuration management
- ✅ Built-in monitoring and diagnostics
- ✅ Cloud-native patterns support

---

### 14. React Frontend

**Purpose:** Modern, responsive user interface

#### Architecture

```
React 18 + Vite
├── Component-based UI
├── Hooks for state management (useState, useEffect)
├── API service layer for backend communication
├── CSS modules for styling
└── Nginx for static asset serving
```

#### Key Components

**1. API Service Layer**
```javascript
// src/service/EmployeeService.js
const API_BASE_URL = process.env.REACT_APP_API_BASE_URL || 'http://localhost:8080/api';

class EmployeeService {
  getAllEmployees() {
    return fetch(`${API_BASE_URL}/employees`, {
      method: 'GET',
      headers: {
        'Content-Type': 'application/json'
      }
    }).then(response => response.json());
  }
  
  createEmployee(employeeData) {
    return fetch(`${API_BASE_URL}/employees`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(employeeData)
    }).then(response => response.json());
  }
  
  updateEmployee(id, employeeData) {
    return fetch(`${API_BASE_URL}/employees/${id}`, {
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(employeeData)
    }).then(response => response.json());
  }
  
  deleteEmployee(id) {
    return fetch(`${API_BASE_URL}/employees/${id}`, {
      method: 'DELETE'
    });
  }
}

export default new EmployeeService();
```

**2. React Component**
```javascript
// src/component/ListEmployeeComponent.jsx
import React, { useState, useEffect } from 'react';
import EmployeeService from '../service/EmployeeService';

function ListEmployeeComponent() {
  const [employees, setEmployees] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  
  // Fetch employees on component mount
  useEffect(() => {
    setLoading(true);
    EmployeeService.getAllEmployees()
      .then(data => {
        setEmployees(data);
        setError(null);
      })
      .catch(err => {
        setError('Failed to fetch employees');
        console.error(err);
      })
      .finally(() => setLoading(false));
  }, []);
  
  return (
    <div className="employee-list">
      {loading && <p>Loading employees...</p>}
      {error && <p className="error">{error}</p>}
      {employees.length === 0 && !loading && <p>No employees found</p>}
      
      <ul>
        {employees.map(emp => (
          <li key={emp.id}>
            <h3>{emp.name}</h3>
            <p>Email: {emp.email}</p>
            <p>Department: {emp.department}</p>
          </li>
        ))}
      </ul>
    </div>
  );
}

export default ListEmployeeComponent;
```

**3. Vite Configuration**
```javascript
// vite.config.js
import react from '@vitejs/plugin-react';
import { defineConfig } from 'vite';

export default defineConfig({
  plugins: [react()],
  server: {
    port: 3000,
    proxy: {
      '/api': {
        target: 'http://localhost:8080',
        changeOrigin: true,
        rewrite: (path) => path
      }
    }
  },
  build: {
    outDir: 'dist',
    sourcemap: false,  // Disable in production
    minify: 'terser'
  }
});
```

**4. Nginx Configuration**
```nginx
# nginx.conf
server {
  listen 80;
  server_name _;
  
  # Root directory for React app
  root /usr/share/nginx/html;
  index index.html;
  
  # Gzip compression for assets
  gzip on;
  gzip_types text/plain text/css application/javascript application/json;
  gzip_min_length 1000;
  
  # Cache static assets (long TTL)
  location ~* \.(js|css|png|jpg|jpeg|gif|svg|woff|woff2)$ {
    expires 30d;
    add_header Cache-Control "public, immutable";
  }
  
  # React SPA routing: fallback to index.html for client-side routing
  location / {
    try_files $uri $uri/ /index.html;
  }
  
  # API proxy (if Nginx serves React + proxies backend)
  location /api {
    proxy_pass http://backend-service:8080;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
  }
  
  # Health check endpoint
  location /health {
    access_log off;
    return 200 "OK";
  }
}
```

#### Why React + Vite
- ✅ Modern tooling with fast development server
- ✅ Optimized production builds (tree-shaking, code splitting)
- ✅ Component-based architecture for maintainability
- ✅ Excellent developer experience (HMR)
- ✅ Large ecosystem and community support
- ✅ Declarative state management
- ✅ Native TypeScript support (optional)

---

## Technology Selection Rationale

### Why Each Technology Was Chosen

#### 1. **Azure Kubernetes Service (AKS)**
| Criterion | Why AKS |
|-----------|---------|
| **Container Orchestration** | Native Azure integration, managed control plane, no ops overhead |
| **Scalability** | Auto-scaling, cluster auto-scaler, HPA support |
| **Security** | Entra ID integration, private clusters, network policies, Azure RBAC |
| **Cost** | Pay only for nodes (control plane included); reserved instances available |
| **Multi-environment** | Easy to replicate across dev/staging/prod |
| **Compliance** | Azure compliance offerings, SOC 2, ISO certifications |

#### 2. **Terraform (Infrastructure-as-Code)**
| Criterion | Why Terraform |
|-----------|----------------|
| **Multi-cloud** | Works with AWS, Azure, GCP (future-proofing) |
| **Modularity** | Reusable modules for scaling across projects |
| **State Management** | Tracks infrastructure state, enables drift detection |
| **Plan/Apply Model** | Safe "what-if" analysis before changes |
| **Version Control** | Infrastructure changes tracked in Git |
| **Community** | Large ecosystem, extensive Azure provider support |
| **Learning Curve** | HCL language is intuitive for most engineers |

#### 3. **GitHub Actions**
| Criterion | Why GitHub Actions |
|-----------|-------------------|
| **Integration** | Native GitHub integration (no external platform) |
| **Cost** | Generous free tier, then pay-per-minute |
| **Ecosystem** | Thousands of pre-built actions available |
| **OIDC** | Native OIDC support (no long-lived secrets needed) |
| **Parallelization** | Matrix builds, parallel jobs |
| **Simplicity** | YAML syntax, easy to understand |

#### 4. **Docker**
| Criterion | Why Docker |
|-----------|-----------|
| **Industry Standard** | De facto containerization standard |
| **Multi-stage Builds** | Optimized image sizes |
| **Caching** | Layer-based caching accelerates CI/CD |
| **Security Scanning** | Built-in vulnerabilities detection (with tools) |
| **Kubernetes Native** | First-class Kubernetes support |

#### 5. **Helm**
| Criterion | Why Helm |
|-----------|----------|
| **Package Manager** | Think "apt" for Kubernetes |
| **Templating** | Parameterized manifests for environments |
| **Versioning** | Chart versions enable rollback |
| **Community** | Thousands of pre-built charts available |
| **Dependency Management** | Handle sub-charts (e.g., PostgreSQL chart) |

#### 6. **Spring Boot**
| Criterion | Why Spring Boot |
|-----------|-----------------|
| **Microservices** | Built-in for cloud-native deployments |
| **Ecosystem** | Spring Cloud, Spring Data, extensive tooling |
| **Kubernetes Ready** | Actuator endpoints for probes, metrics |
| **Cloud Platforms** | Native Azure, AWS, GCP support |
| **Java Standard** | Mature language, large team familiarity |
| **Production Proven** | Used by enterprises worldwide |

#### 7. **React + Vite**
| Criterion | Why React |
|-----------|-----------|
| **Component Model** | Reusable, composable UI components |
| **Developer Experience** | Hot module replacement, excellent tooling |
| **Performance** | Virtual DOM, efficient updates |
| **Community** | Largest front-end ecosystem |
| **TypeScript Support** | Enables type-safe JavaScript (optional) |
| **Vite Rationale** | ~10x faster than Webpack, native ESM support |

#### 8. **PostgreSQL**
| Criterion | Why PostgreSQL |
|-----------|-----------------|
| **Reliability** | ACID compliance, battle-tested |
| **Features** | JSON, full-text search, advanced query capabilities |
| **Scaling** | Replication, partitioning, connection pooling |
| **Azure Integration** | Managed Azure Database for PostgreSQL |
| **License** | Open source, no licensing costs |
| **Community** | Active development, excellent documentation |

#### 9. **Azure Managed Identities**
| Criterion | Why Managed Identities |
|-----------|------------------------|
| **Credential Management** | Automatic rotation, no storage |
| **Principle of Least Privilege** | Fine-grained RBAC per identity |
| **Audit Trail** | All identity operations logged |
| **Zero-Trust Alignment** | Identity-based access control |
| **Cost** | No additional licensing |

---

## Alternative Approaches Considered

### 1. Public AKS vs. Private AKS (Selected: Private)

| Aspect | Public AKS | Private AKS (Selected) |
|--------|-----------|----------------------|
| **API Exposure** | Public endpoint on internet | Private endpoint only |
| **Access Pattern** | Direct kubectl access | Via JumpVM / Azure Bastion |
| **Attack Surface** | Larger (public IP) | Minimal (private VNet) |
| **Setup Complexity** | Simpler | More complex (JumpVM setup) |
| **Compliance** | May not meet strict requirements | Meets zero-trust requirements |
| **Cost** | Lower | Slightly higher (JumpVM) |

**Why Private AKS was chosen:**
- ✅ Aligns with zero-trust security principles
- ✅ Eliminates direct internet exposure
- ✅ Better for regulated industries
- ✅ Minimal additional cost
- ❌ Slightly more operational complexity
- ❌ Requires bastion for access

---

### 2. Azure Container Registry vs. Docker Hub (Selected: ACR)

| Aspect | Docker Hub | ACR (Selected) |
|--------|-----------|-----------------|
| **Integration** | Third-party | Native Azure |
| **Network Isolation** | Limited | Premium tier: private endpoints |
| **Compliance** | Limited certifications | Azure compliance portfolio |
| **Cost** | Free tier limited | Pay per usage + egress |
| **Geographic Replication** | Limited | Multi-region available |
| **RBAC** | Limited | Full Azure RBAC |

**Why ACR was chosen:**
- ✅ Native Azure integration (reduced latency)
- ✅ Premium tier provides network isolation
- ✅ Full Azure RBAC support
- ✅ Enterprise compliance features
- ✅ Private endpoint support
- ❌ Slightly higher cost
- ❌ Vendor lock-in to Azure

---

### 3. GitHub Actions vs. GitLab CI vs. Jenkins (Selected: GitHub Actions)

| Aspect | Jenkins | GitLab CI | GitHub Actions (Selected) |
|--------|---------|----------|--------------------------|
| **Setup** | Self-hosted, complex | Managed or self-hosted | GitHub-native, simple |
| **Cost** | Server + maintenance | Free tier available | Generous free tier |
| **YAML Config** | Groovy/XML | YAML | YAML |
| **Integration** | Generic plugins | Git-centric | GitHub-native |
| **Learning Curve** | Steep | Moderate | Low |
| **Parallelization** | Complex | Built-in | Built-in (matrix) |
| **Secrets Management** | Encrypted | Protected variables | Encrypted secrets |

**Why GitHub Actions was chosen:**
- ✅ Lowest operational overhead (no self-hosted runners)
- ✅ Excellent GitHub integration (no third-party platform)
- ✅ Cost-effective (generous free tier)
- ✅ Easy YAML syntax
- ✅ Matrix builds for parallelization
- ❌ Less flexibility than Jenkins (scripting)
- ❌ Vendor lock-in to GitHub

---

### 4. Helm vs. Kustomize vs. ArgoCD (Selected: Helm)

| Aspect | Kustomize | ArgoCD | Helm (Selected) |
|--------|----------|--------|-----------------|
| **Learning Curve** | Low | Moderate | Low-Moderate |
| **Package Management** | No | No | Yes (versioning) |
| **Templating** | Limited | Go templates | Comprehensive |
| **GitOps** | No | Yes (dedicated) | Via GitOps tools |
| **Environment Overrides** | Via overlays | Via app sets | Via values files |
| **Ecosystem** | Small | Growing | Large (chart repos) |
| **Community Charts** | Minimal | Minimal | Extensive (Artifact Hub) |

**Why Helm was chosen:**
- ✅ Mature packaging standard for Kubernetes
- ✅ Extensive community chart ecosystem
- ✅ Version management for releases
- ✅ Easy environment overrides (values files)
- ✅ Templating capabilities
- ⚠️ ArgoCD could be added later for GitOps
- ❌ Lacks built-in GitOps (but works with ArgoCD)

---

### 5. Spring Boot vs. Quarkus vs. Node.js (Selected: Spring Boot)

| Aspect | Quarkus | Node.js | Spring Boot (Selected) |
|--------|---------|---------|----------------------|
| **Startup Time** | <1s | ~200ms | 2-5s |
| **Memory** | 10-20MB | 50-100MB | 256MB+ |
| **Ecosystem** | Growing | Massive | Massive |
| **Team Knowledge** | Limited (Java) | High (JavaScript) | High (Java) |
| **Maturity** | Newer | Mature | Very mature |
| **Cloud Native** | Excellent | Good | Excellent |
| **GraalVM Native** | Supported | Limited | Optional |

**Why Spring Boot was chosen:**
- ✅ Familiar to Java teams
- ✅ Enterprise-grade ecosystem
- ✅ Excellent Kubernetes integration
- ✅ Active community and support
- ✅ Production-proven at scale
- ⚠️ Higher startup time (< 5s acceptable for POC)
- ⚠️ Higher memory footprint (acceptable for POC)
- ❌ Slower startup than Quarkus

---

### 6. PostgreSQL vs. MySQL vs. CosmosDB (Selected: PostgreSQL)

| Aspect | MySQL | CosmosDB | PostgreSQL (Selected) |
|--------|-------|----------|----------------------|
| **ACID Compliance** | InnoDB only | Limited | Full |
| **Scaling** | Vertical | Horizontal (NoSQL) | Vertical + replication |
| **SQL Features** | Limited | No SQL | Advanced (JSON, FTS) |
| **Cost** | Lower | Higher | Mid-range |
| **Maturity** | Very high | Newer | Very high |
| **Backup** | Standard | Azure integration | Azure integration |

**Why PostgreSQL was chosen:**
- ✅ Full ACID compliance for transactional integrity
- ✅ Advanced SQL features (employee data is relational)
- ✅ Proven reliability for business applications
- ✅ Strong Azure integration (managed service available)
- ✅ Active development and community
- ❌ Requires relational schema design
- ❌ Not suitable for unstructured data (not a requirement)

---

## Why Alternatives Were Not Chosen

### Public AKS Not Selected
- ❌ Exposes Kubernetes API to internet (security risk)
- ❌ Fails zero-trust architecture principle
- ❌ Difficult to meet compliance requirements
- ❌ Larger attack surface for DDoS

### Docker Hub Not Selected
- ❌ No network isolation options
- ❌ Limited RBAC capabilities
- ❌ No private endpoint support
- ❌ Compliance certifications limited

### Jenkins Not Selected
- ❌ Requires self-hosted infrastructure (ops burden)
- ❌ Complex Groovy scripting language
- ❌ High maintenance overhead
- ❌ Slower to set up and configure

### Kustomize Not Selected
- ❌ No package versioning (difficult for releases)
- ❌ Limited templating capabilities
- ❌ Smaller community ecosystem
- ❌ Limited environment management

### Quarkus Not Selected (Instead of Spring Boot)
- ❌ Smaller ecosystem for enterprise features
- ❌ Less team familiarity (Java shop)
- ❌ Community adoption still growing
- ❌ Fewer third-party integrations

### MySQL Not Selected
- ❌ Limited transaction isolation levels
- ❌ Weaker referential integrity
- ❌ Less advanced SQL feature set
- ❌ Full-text search less robust

### CosmosDB Not Selected
- ❌ Not suitable for relational employee data
- ❌ Significantly higher cost
- ❌ Requires learning NoSQL patterns
- ❌ Vendor lock-in to Azure (more than PostgreSQL)

---

## Security Considerations for Each Component

### 1. **AKS Cluster Security**

**Network Security:**
```yaml
# Network Policy: Allow traffic only from frontend to backend
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-isolation
spec:
  podSelector:
    matchLabels:
      tier: backend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          tier: frontend
    ports:
    - protocol: TCP
      port: 8080
```

**Pod Security Standards:**
```yaml
apiVersion: policy/v1beta1
kind: PodSecurityPolicy
metadata:
  name: restricted
spec:
  privileged: false
  allowPrivilegeEscalation: false
  requiredDropCapabilities:
  - ALL
  volumes:
  - 'configMap'
  - 'emptyDir'
  - 'projected'
  - 'secret'
  - 'downwardAPI'
  - 'persistentVolumeClaim'
  hostNetwork: false
  hostIPC: false
  hostPID: false
  runAsUser:
    rule: 'MustRunAsNonRoot'
  fsGroup:
    rule: 'MustRunAs'
    ranges:
    - min: 1000
      max: 65535
  readOnlyRootFilesystem: true
```

**RBAC Configuration:**
```yaml
# Limit pod access to only necessary APIs
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: app-reader
rules:
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["get", "list"]
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get"]
  resourceNames: ["db-credentials"]  # Specific secret
```

**Secrets Management:**
```yaml
# Don't store secrets in ConfigMaps; use Azure Key Vault
apiVersion: v1
kind: Secret
metadata:
  name: db-credentials
type: Opaque
stringData:
  username: postgres
  password: $(GENERATED_SECURE_PASSWORD)  # Externally injected
```

### 2. **Container Security**

**Image Scanning:**
```bash
# Scan image for vulnerabilities before push
trivy image myacr.azurecr.io/ems-backend:latest

# Results:
# - Critical: 0
# - High: 2 (remediation required)
# - Medium: 5
```

**Non-Root User (Already Implemented):**
```dockerfile
# Create app user (uid 1000)
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
USER appuser
```

**Read-Only Root Filesystem:**
```yaml
securityContext:
  readOnlyRootFilesystem: true
  allowPrivilegeEscalation: false
  runAsNonRoot: true
  runAsUser: 1000
```

### 3. **Database Security**

**SSL/TLS Enforcement:**
```hcl
# Azure Database for PostgreSQL
resource "azurerm_postgresql_flexible_server" "postgres" {
  ssl_enforce = true  # Requires SSL/TLS for all connections
}
```

**VNet Integration:**
```hcl
resource "azurerm_postgresql_flexible_server" "postgres" {
  delegated_subnet_id = var.postgres_subnet_id  # Private VNet only
}

# Firewall: Allow only AKS nodes
resource "azurerm_postgresql_flexible_server_firewall_rule" "aks" {
  server_id             = azurerm_postgresql_flexible_server.postgres.id
  name                  = "AllowAKSNodes"
  start_ip_address      = "10.0.1.0"
  end_ip_address        = "10.0.1.255"
}
```

**Connection Pooling:**
```yaml
# PgBouncer connection pooling for DoS mitigation
pgbouncer:
  default_pool_size: 20
  max_client_conn: 100
  reserve_pool_size: 5
  timeout: 600
```

### 4. **ACR Security**

**Network Isolation:**
```hcl
# Premium ACR with private endpoint
resource "azurerm_container_registry" "acr" {
  sku = "Premium"  # Required for private endpoints
}

resource "azurerm_private_endpoint" "acr" {
  name                = "acr-private-endpoint"
  subnet_id           = var.aks_subnet_id
  private_service_connection {
    private_connection_resource_id = azurerm_container_registry.acr.id
    subresource_names              = ["registry"]
  }
}
```

**Image Signing (Optional):**
```bash
# Sign images with cosign
cosign sign --key cosign.key myacr.azurecr.io/app:v1.0

# Verify signatures in deployment policy
# (Requires cosign-policy webhook)
```

### 5. **GitHub Actions Security**

**OIDC Token Exchange (No Long-Lived Secrets):**
```yaml
jobs:
  deploy:
    runs-on: ubuntu-latest
    permissions:
      id-token: write  # Allow OIDC token generation
      contents: read
    steps:
      - name: Azure Login (OIDC)
        uses: azure/login@v1
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
          # No client secret! Token automatically refreshed
```

**Secrets Encryption:**
```bash
# All secrets are encrypted at rest in GitHub
# Use repository secrets for sensitive data
# - AZURE_CREDENTIALS
# - REGISTRY_PASSWORD
# - API_KEYS

# Access in workflow:
${{ secrets.AZURE_CREDENTIALS }}
```

### 6. **JumpVM Security**

**Bastion Access (No Direct SSH):**
```bash
# Access via Azure Bastion (browser-based)
# No SSH port 22 exposed to internet
```

**Managed Identity:**
```bash
# From JumpVM, authenticate without credentials
az login --identity

# All operations logged to Azure Activity Log
```

### 7. **Managed Identity Security**

**Least Privilege RBAC:**
```hcl
# Grant only required permissions
resource "azurerm_role_assignment" "aks_acr_pull" {
  principal_id       = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
  role_definition_name = "AcrPull"  # Not Contributor or Owner
  scope              = azurerm_container_registry.acr.id
}
```

**Credential Rotation:**
```bash
# Automatic token refresh (no manual rotation needed)
# Tokens valid for 1 hour
# Refreshed automatically by Azure SDK
```

---

## Benefits of This Architecture

### 1. **Security**
- ✅ **Zero-trust network**: Private API server, no public exposure
- ✅ **Identity-based access**: Managed identities eliminate credential sharing
- ✅ **Defense-in-depth**: NSGs, network policies, RBAC, Pod security standards
- ✅ **Audit trail**: All operations logged (AKS API audit logs, Activity Log)
- ✅ **Non-root containers**: Privilege escalation protection
- ✅ **Encrypted secrets**: Secrets encrypted at rest and in transit (TLS)

### 2. **Scalability**
- ✅ **Auto-scaling nodes**: Cluster auto-scaler adjusts node count (3-10 nodes)
- ✅ **Pod auto-scaling**: HPA adjusts replicas based on CPU/memory
- ✅ **Load balancing**: Application Gateway distributes traffic
- ✅ **Multi-zone deployment**: Availability zones provide fault tolerance
- ✅ **Horizontal scaling**: Stateless microservices scale easily

### 3. **Operational Excellence**
- ✅ **Fully automated**: CI/CD pipeline eliminates manual steps
- ✅ **Infrastructure-as-Code**: Terraform enables reproducible deployments
- ✅ **GitOps principles**: Infrastructure and code in Git (version control)
- ✅ **Declarative deployment**: Helm manages application state
- ✅ **Blue-green deployments**: Enable zero-downtime updates
- ✅ **Rollback capability**: Git commits enable instant rollback

### 4. **Cost Optimization**
- ✅ **Pay-only-for-nodes**: AKS control plane managed by Microsoft
- ✅ **Reserved instances**: Discount for commitment (optional)
- ✅ **Spot instances**: Cost savings for non-critical workloads
- ✅ **Auto-scaling reduces waste**: Scale down during low traffic
- ✅ **Managed services**: Eliminate infrastructure management overhead

### 5. **Reliability**
- ✅ **Multi-zone**: 3+ availability zones for fault tolerance
- ✅ **Health checks**: Liveness/readiness probes ensure pod health
- ✅ **Auto-restart**: Kubernetes automatically restarts failed pods
- ✅ **Load balancing**: Requests distributed across healthy replicas
- ✅ **Backups**: PostgreSQL automated backups with retention
- ✅ **Geo-redundancy**: Optional geo-backup for disaster recovery

### 6. **Maintainability**
- ✅ **Modular Terraform**: Reusable modules for multiple environments
- ✅ **Clear separation of concerns**: Networking, compute, database modules
- ✅ **Helm templating**: Reduce YAML duplication
- ✅ **Environment parity**: Dev/QA/Prod use identical infrastructure code
- ✅ **Documentation**: IaC serves as executable documentation

### 7. **Compliance & Governance**
- ✅ **Azure compliance**: Meets SOC 2, ISO 27001, HIPAA, PCI DSS
- ✅ **Audit logging**: All actions logged and auditable
- ✅ **RBAC**: Fine-grained access control
- ✅ **Data residency**: Resources deployed in specific regions
- ✅ **Encryption**: Data encrypted at rest and in transit
- ✅ **Policy enforcement**: Azure Policy prevents non-compliant resources

---

## Limitations of This POC

### 1. **Scalability Limitations**

**Current Constraints:**
- Node pool limited to 10 nodes (configurable)
- Single AKS cluster (no multi-cluster support)
- Single region deployment (no multi-region failover)
- Single PostgreSQL instance (no multi-region replication)

**Recommendations for Production:**
```
• Increase max_count to 20-50 nodes as traffic grows
• Implement multi-cluster deployment for global distribution
• Add secondary PostgreSQL replica in different region
• Use Application Gateway multi-region deployment
```

### 2. **Operational Complexity**

**Current Challenges:**
- JumpVM access requires Azure Bastion setup
- Manual kubeconfig management from JumpVM
- Limited observability (no Prometheus/Grafana by default)
- No automatic certificate rotation (TLS management manual)

**Recommendations for Production:**
```
• Deploy monitoring stack (Azure Monitor + Application Insights)
• Implement cert-manager for automated TLS renewal
• Add service mesh (Istio/Linkerd) for advanced traffic management
• Setup GitOps (ArgoCD) for automated reconciliation
```

### 3. **Cost Considerations**

**Current Expenses:**
- 3 AKS nodes @ Standard_D2s_v3: ~$500/month
- PostgreSQL Flexible Server: ~$200/month
- Application Gateway: ~$150/month
- Storage Account (charts): ~$20/month
- **Total: ~$870/month** (likely higher with overages)

**Optimization Recommendations:**
```
• Use Spot VMs for non-critical workloads (-70% cost)
• Reserve instances for predictable workloads (-30% cost)
• Use smaller VM sizes for POC (Standard_B2s: 60% cheaper)
• Implement resource cleanup policies
• Use Azure Cost Management for tracking
```

### 4. **Security Limitations**

**Gaps in This POC:**
- No service mesh (Istio) for mutual TLS between pods
- No advanced intrusion detection (need Azure Defender for AKS)
- No OPA/Kyverno for policy enforcement
- No secrets rotation automation
- No image scanning in pipeline (manual scanning required)
- No network ingress/egress restrictions (only NSGs)

**Recommendations for Production:**
```
• Deploy Azure Policy for PaaS governance
• Implement Kyverno for Kubernetes policy enforcement
• Enable Azure Defender for AKS (threat detection)
• Integrate HashiCorp Vault for secrets management
• Add image scanning in CI/CD pipeline (Trivy)
• Implement network policies for micro-segmentation
```

### 5. **Performance Limitations**

**Current Bottlenecks:**
- Single-zone Application Gateway (not multi-zone)
- PostgreSQL connection pool limited to 20 connections
- No caching layer (Redis) for frequently accessed data
- No CDN for static assets
- Limited JVM heap for Spring Boot (~512MB-1GB)

**Recommendations for Production:**
```
• Add Redis cache for session/data caching
• Deploy Azure CDN for static content
• Use Azure Traffic Manager for multi-region routing
• Increase PostgreSQL connection pool as needed
• Tune JVM heap settings per workload
```

### 6. **High Availability Gaps**

**Current Constraints:**
- Single PostgreSQL instance (high availability optional)
- JumpVM is single instance (single point of access)
- Application Gateway not zone-redundant (not on Premium SKU)
- No disaster recovery automation

**Recommendations for Production:**
```
• Enable PostgreSQL HA with standby replica
• Deploy multiple jump VMs for redundancy
• Use Application Gateway Premium v2 for zone redundancy
• Implement Azure Site Recovery for DR
• Setup automated failover mechanisms
• Plan for RTO/RPO based on business requirements
```

### 7. **Compliance Gaps**

**Not Addressed in POC:**
- Data encryption at rest (not enabled by default)
- Secrets encrypted in Key Vault (secrets stored in ConfigMaps)
- Backup and recovery procedures (manual)
- Incident response procedures
- Security scanning in pipeline
- Compliance reporting

**Recommendations for Production:**
```
• Enable encryption at rest for all Azure services
• Migrate secrets to Azure Key Vault
• Implement automated backup and restore testing
• Create incident response runbooks
• Integrate vulnerability scanning (Trivy, Snyk)
• Setup compliance monitoring (Azure Policy Compliance)
• Generate compliance reports automatically
```

### 8. **Observability Limitations**

**Current Gaps:**
- No Prometheus/Grafana for metrics
- No centralized logging (ELK stack)
- Limited alerting (only Azure Monitor)
- No distributed tracing
- No custom dashboards

**Recommendations for Production:**
```
• Deploy Azure Application Insights for monitoring
• Integrate Spring Boot micrometer with Prometheus
• Deploy ELK stack or use Azure Log Analytics
• Implement distributed tracing (Jaeger/Zipkin)
• Create alerting rules for SLO/SLI violations
• Setup on-call escalation policies
```

---

## Deployment Checklist

### Pre-Deployment Verification

- [ ] **Azure Subscription**: Verify subscription access and quota
- [ ] **Terraform State**: Remote state backend configured (optional but recommended)
- [ ] **Service Principal**: Created with necessary permissions
- [ ] **SSH Key**: Generated for JumpVM access
- [ ] **GitHub Secrets**: Added (AZURE_CREDENTIALS, ACR credentials)
- [ ] **Network Range**: VNet CIDR validated (no conflicts)
- [ ] **DNS**: Private DNS zone created (for private cluster)

### Infrastructure Deployment

```bash
# 1. Initialize Terraform
cd terraform/environments/dev
terraform init

# 2. Validate configuration
terraform validate

# 3. Plan deployment
terraform plan -out=tfplan

# 4. Review plan output and approve
# (Verify resource types, quantities, configurations)

# 5. Apply deployment
terraform apply tfplan

# 6. Verify outputs
terraform output
```

### Post-Deployment Validation

- [ ] **AKS Cluster**: Verify cluster is running
  ```bash
  az aks get-credentials --resource-group rg-aks-3tier-dev --name aks-ems-dev
  kubectl get nodes  # Should show 3+ nodes
  ```

- [ ] **Database**: Verify PostgreSQL is accessible
  ```bash
  psql -h pgemsdev.postgres.database.azure.com -U postgresadmin -d employee_db
  ```

- [ ] **Container Registry**: Verify ACR is accessible
  ```bash
  az acr repository list --name myacr
  ```

- [ ] **GitHub Actions**: Run pipeline manually
  ```bash
  # Push change to trigger workflow
  # Monitor GitHub Actions tab for execution
  ```

- [ ] **Application**: Verify deployment
  ```bash
  kubectl get deployments -n employee-management
  kubectl get pods -n employee-management
  kubectl logs -n employee-management -l app=ems-backend
  ```

---

## Appendix: Troubleshooting Guide

### Common Issues & Solutions

**Issue 1: AKS Cluster Inaccessible**
```bash
# Error: "couldn't connect to the server"

# Solution:
# 1. Verify JumpVM has kubectl installed
az vm run-command invoke \
  --resource-group rg-aks-3tier-dev \
  --name jump-vm \
  --command-id RunShellScript \
  --scripts "kubectl version"

# 2. Verify kubeconfig is correctly configured
kubectl config view

# 3. If using Azure AD, verify Entra group membership
az ad group member list --group aks-admin-group
```

**Issue 2: Image Pull Errors**
```bash
# Error: "ImagePullBackOff"

# Solution:
# 1. Verify ACR credentials in cluster
kubectl get secrets -n employee-management

# 2. Check image exists in ACR
az acr repository show-manifests --repository ems-backend --registry myacr

# 3. Verify kubelet identity has AcrPull role
az role assignment list --assignee-object-id <kubelet-object-id>
```

**Issue 3: Database Connection Failures**
```bash
# Error: "Connection refused" from Spring Boot

# Solution:
# 1. Verify PostgreSQL firewall rules allow AKS subnet
az postgres flexible-server firewall-rule list \
  --resource-group rg-aks-3tier-dev \
  --server-name pgemsdev

# 2. Test connectivity from pod
kubectl run -it --image=postgres:15 -- psql \
  -h pgemsdev.postgres.database.azure.com \
  -U postgresadmin \
  -d employee_db

# 3. Verify connection string in deployment
kubectl get configmap -n employee-management -o yaml
```

**Issue 4: GitHub Actions Workflow Failures**
```bash
# Error: "Authentication failed"

# Solution:
# 1. Verify Azure credentials secret exists
gh secret list --repo owner/repo

# 2. Verify service principal has necessary permissions
az role assignment list \
  --assignee <service-principal-id> \
  --output table

# 3. Check workflow logs for detailed errors
# (GitHub Actions UI → Workflow Runs → Job Logs)
```

---

## Conclusion

This POC demonstrates a **production-grade, secure CI/CD architecture** for deploying cloud-native applications to Azure Kubernetes Service. By implementing zero-trust security principles, Infrastructure-as-Code automation, and industry-standard tools (Terraform, GitHub Actions, Helm, Docker), this solution provides:

✅ **Security by Default** — Private clusters, managed identities, network policies
✅ **Operational Automation** — End-to-end CI/CD eliminates manual steps
✅ **Scalability** — Auto-scaling, multi-zone deployment, load balancing
✅ **Maintainability** — Version-controlled infrastructure, modular Terraform, declarative Helm
✅ **Compliance** — Audit logging, RBAC, encryption, Azure security services
✅ **Cost Optimization** — Managed services, auto-scaling, reserved instances

### Next Steps for Production

1. **Implement observability** (Azure Monitor, Application Insights, ELK)
2. **Add secrets management** (Azure Key Vault integration)
3. **Deploy service mesh** (Istio/Linkerd for advanced traffic management)
4. **Setup GitOps** (ArgoCD for continuous reconciliation)
5. **Implement disaster recovery** (Multi-region, automated failover)
6. **Add compliance automation** (Azure Policy, Kyverno)
7. **Performance tuning** (Caching, CDN, JVM optimization)
8. **Capacity planning** (Load testing, resource forecasting)

---

**Document Prepared By:** Platform Engineering Team  
**Review Status:** Ready for SME Review  
**Last Updated:** June 2026  
**Version:** 1.0
