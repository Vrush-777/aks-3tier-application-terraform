# Kubernetes Deployment Guide - AKS with AGIC

## Table of Contents
1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Prerequisites](#prerequisites)
4. [Directory Structure](#directory-structure)
5. [Deployment Instructions](#deployment-instructions)
6. [Verification & Testing](#verification--testing)
7. [Configuration Management](#configuration-management)
8. [Scaling & Updates](#scaling--updates)
9. [Troubleshooting](#troubleshooting)
10. [Production Checklist](#production-checklist)

---

## Overview

This Kubernetes deployment provides a production-ready setup for the EMS three-tier application on Azure AKS (Azure Kubernetes Service) with:

- **AGIC Integration**: Azure Application Gateway Ingress Controller for traffic routing
- **High Availability**: Multi-replica deployments with rolling updates
- **Security**: Non-root users, security contexts, RBAC, and pod disruption budgets
- **Health Management**: Readiness/liveness/startup probes for automatic recovery
- **Configuration Management**: ConfigMaps for non-sensitive config, Secrets for credentials
- **Resource Management**: CPU/memory requests and limits for predictable resource usage
- **Observability**: Metrics endpoints, structured logging, and health checks

---

## Architecture

### Network Flow
```
External Traffic (HTTPS)
       ↓
Azure Application Gateway (AGIC)
       ↓
    ├─ / (root)         → Nginx Frontend Service → Pods
    ├─ /api             → Spring Boot Backend Service → Pods
    └─ /actuator        → Spring Boot Actuator endpoints
       ↓
Internal Service Discovery
       ├─ ems-frontend.dev.svc.cluster.local:80
       ├─ ems-backend.dev.svc.cluster.local:8080
       └─ postgres service in PostgreSQL namespace
```

### Kubernetes Objects

| Resource | Name | Replicas | CPU | Memory |
|----------|------|----------|-----|--------|
| Frontend Deployment | ems-frontend | 2 | 100m-500m | 128Mi-256Mi |
| Backend Deployment | ems-backend | 2 | 250m-1000m | 512Mi-1024Mi |
| Frontend Service | ems-frontend | - | - | - |
| Backend Service | ems-backend | - | - | - |
| Ingress | ems-ingress | - | - | - |

---

## Prerequisites

### Azure Resources
1. **AKS Cluster** (1.27+)
   - Minimum 3 nodes
   - Node VM size: Standard_D2s_v3 or larger
   - Enable monitoring (Log Analytics)

2. **Application Gateway** (v2)
   - Public IP address
   - Minimum Standard tier
   - TLS certificate for HTTPS (optional)

3. **Container Registry**
   - Azure Container Registry (ACR) to store images
   - Images pushed from your build pipeline

4. **PostgreSQL Database**
   - Azure Database for PostgreSQL or managed PostgreSQL in cluster
   - Network connectivity to AKS cluster

### Local Tools
```bash
# Install kubectl
# https://kubernetes.io/docs/tasks/tools/

# Install Azure CLI
az --version

# Install helm (optional, for advanced deployments)
helm version

# Verify connectivity
kubectl cluster-info
kubectl get nodes
```

### Permissions
- Azure subscription with permissions to:
  - Manage AKS clusters
  - Manage Application Gateway
  - Manage Container Registry
  - Manage databases

---

## Directory Structure

```
k8s/
├── namespace/
│   └── namespace.yaml              # dev namespace
├── frontend/
│   ├── deployment.yaml             # Frontend deployment with probes
│   └── service.yaml                # Frontend ClusterIP service + RBAC
├── backend/
│   ├── deployment.yaml             # Backend deployment with health checks
│   ├── service.yaml                # Backend ClusterIP service + RBAC
│   ├── configmap.yaml              # Non-sensitive configuration
│   └── secret.yaml                 # Sensitive credentials
└── ingress/
    └── ingress.yaml                # AGIC ingress routing

Total: 9 YAML files, fully commented and production-ready
```

---

## Deployment Instructions

### Step 1: Prepare Container Images

Push images to Azure Container Registry:

```bash
# Login to ACR
az acr login --name <registry-name>

# Build and push frontend
docker build -f ems-fullstack/Dockerfile -t <registry-name>.azurecr.io/ems-frontend:latest .
docker push <registry-name>.azurecr.io/ems-frontend:latest

# Build and push backend
docker build -f ems-backend/ems-backend/Dockerfile -t <registry-name>.azurecr.io/ems-backend:latest .
docker push <registry-name>.azurecr.io/ems-backend:latest

# Verify images
az acr repository list --name <registry-name>
```

### Step 2: Update Image References

Edit `k8s/frontend/deployment.yaml` and `k8s/backend/deployment.yaml`:

```yaml
containers:
  - name: nginx/spring-boot
    image: <registry-name>.azurecr.io/ems-frontend:latest
    # or
    image: <registry-name>.azurecr.io/ems-backend:latest
```

### Step 3: Configure AKS Credentials

```bash
# Get AKS cluster credentials
az aks get-credentials \
  --resource-group <resource-group> \
  --name <cluster-name>

# Verify connection
kubectl cluster-info
kubectl get nodes
```

### Step 4: Create Namespace

```bash
# Create the dev namespace
kubectl apply -f k8s/namespace/namespace.yaml

# Verify
kubectl get namespace dev
kubectl describe namespace dev
```

### Step 5: Create Backend Configuration

```bash
# Create ConfigMap (non-sensitive config)
kubectl apply -f k8s/backend/configmap.yaml -n dev

# Create Secret (sensitive credentials)
# First, generate base64 encoded password
echo -n 'your-secure-database-password' | base64

# Update secret.yaml with the base64 value, then apply
kubectl apply -f k8s/backend/secret.yaml -n dev

# Verify
kubectl get configmap -n dev
kubectl get secret -n dev
```

### Step 6: Deploy Frontend

```bash
# Create frontend deployment and service
kubectl apply -f k8s/frontend/deployment.yaml -n dev
kubectl apply -f k8s/frontend/service.yaml -n dev

# Wait for pods to be ready (2-3 minutes)
kubectl get pods -n dev -l app=ems-frontend
kubectl wait --for=condition=ready pod -l app=ems-frontend -n dev --timeout=300s

# Verify service
kubectl get svc -n dev ems-frontend
```

### Step 7: Deploy Backend

```bash
# Create backend deployment and service
kubectl apply -f k8s/backend/deployment.yaml -n dev
kubectl apply -f k8s/backend/service.yaml -n dev

# Wait for pods to be ready (2-3 minutes)
kubectl get pods -n dev -l app=ems-backend
kubectl wait --for=condition=ready pod -l app=ems-backend -n dev --timeout=300s

# Verify service
kubectl get svc -n dev ems-backend
```

### Step 8: Deploy Ingress (AGIC)

```bash
# Verify AGIC is installed in cluster
kubectl get pods -n kube-system | grep ingress-azure

# If AGIC is not installed, install it first:
# https://learn.microsoft.com/en-us/azure/application-gateway/ingress-controller-install-new

# Deploy ingress
kubectl apply -f k8s/ingress/ingress.yaml -n dev

# Wait for ingress to be assigned
kubectl get ingress -n dev

# Describe ingress to see details
kubectl describe ingress ems-ingress -n dev
```

### Step 9: Verify AGIC Configuration

```bash
# Check AGIC controller logs
kubectl logs -n kube-system -l app=ingress-azure -f

# Get Application Gateway public IP
az network public-ip show \
  --name <public-ip-name> \
  --resource-group <resource-group> \
  --query ipAddress -o tsv
```

---

## Verification & Testing

### 1. Check Pod Status

```bash
# All pods in dev namespace
kubectl get pods -n dev

# Expected output:
# NAME                              READY   STATUS    RESTARTS   AGE
# ems-frontend-xxxxx-xxxxx          1/1     Running   0          2m
# ems-frontend-xxxxx-xxxxx          1/1     Running   0          2m
# ems-backend-xxxxx-xxxxx           1/1     Running   0          2m
# ems-backend-xxxxx-xxxxx           1/1     Running   0          2m

# View pod details
kubectl describe pod <pod-name> -n dev
```

### 2. Check Service Status

```bash
# List all services
kubectl get svc -n dev

# Expected:
# NAME           TYPE        CLUSTER-IP     PORT(S)  
# ems-frontend   ClusterIP   [REDACTED_IPV4_ADDRESS_3]/24       80/TCP
# ems-backend    ClusterIP   [REDACTED_IPV4_ADDRESS_4]/24       8080/TCP

# Test internal service discovery
kubectl run -it --rm debug --image=busybox --restart=Never -- \
  wget -O - http://ems-frontend.dev.svc.cluster.local
```

### 3. Check Ingress Status

```bash
# List ingress
kubectl get ingress -n dev

# Get detailed information
kubectl describe ingress ems-ingress -n dev

# Check AGIC logs
kubectl logs -n kube-system -l app=ingress-azure --tail=50
```

### 4. Test Endpoints

```bash
# Get the public IP from Application Gateway
PUBLIC_IP=$(az network public-ip show \
  --name <public-ip-name> \
  --resource-group <resource-group> \
  --query ipAddress -o tsv)

# Test frontend
curl http://$PUBLIC_IP/

# Test backend API
curl http://$PUBLIC_IP/api/employees

# Test health endpoints
curl http://$PUBLIC_IP/health
curl http://$PUBLIC_IP/actuator/health
```

### 5. View Logs

```bash
# Frontend pod logs
kubectl logs <frontend-pod-name> -n dev

# Backend pod logs
kubectl logs <backend-pod-name> -n dev -f

# All pods of a deployment
kubectl logs -n dev -l app=ems-backend --all-containers=true

# Previous logs (if crashed)
kubectl logs <pod-name> -n dev --previous
```

---

## Configuration Management

### Updating ConfigMap

```bash
# Edit ConfigMap
kubectl edit configmap ems-backend-config -n dev

# Or apply from file
kubectl apply -f k8s/backend/configmap.yaml -n dev

# Restart deployment to pick up changes
kubectl rollout restart deployment/ems-backend -n dev

# Check status
kubectl rollout status deployment/ems-backend -n dev
```

### Updating Secret

```bash
# Delete old secret
kubectl delete secret ems-backend-secrets -n dev

# Create new secret
kubectl create secret generic ems-backend-secrets \
  --from-literal=DB_[REDACTED_GENERIC_PASSWORD_1]='new-password' \
  -n dev

# Or apply from updated YAML file
kubectl apply -f k8s/backend/secret.yaml -n dev

# Restart to pick up changes
kubectl rollout restart deployment/ems-backend -n dev
```

### Environment Variables

Add environment variables to deployments:

```bash
# Set environment variable
kubectl set env deployment/ems-backend \
  LOG_LEVEL=DEBUG \
  -n dev

# View current env vars
kubectl set env deployment/ems-backend --list -n dev

# Remove env var
kubectl set env deployment/ems-backend \
  LOG_LEVEL- \
  -n dev
```

---

## Scaling & Updates

### Scale Deployments

```bash
# Scale frontend to 3 replicas
kubectl scale deployment ems-frontend --replicas=3 -n dev

# Scale backend to 4 replicas
kubectl scale deployment ems-backend --replicas=4 -n dev

# Auto-scaling with HPA (optional)
kubectl autoscale deployment ems-backend \
  --min=2 --max=10 \
  --cpu-percent=80 \
  -n dev
```

### Update Container Images

```bash
# Update frontend image
kubectl set image deployment/ems-frontend \
  nginx=<registry>/ems-frontend:v1.1 \
  -n dev

# Update backend image
kubectl set image deployment/ems-backend \
  spring-boot=<registry>/ems-backend:v1.1 \
  -n dev

# Check rollout status
kubectl rollout status deployment/ems-frontend -n dev

# Rollback if needed
kubectl rollout undo deployment/ems-frontend -n dev
```

### Rolling Updates

The deployments use rolling update strategy with:
- `maxSurge: 1` - Allow 1 extra pod during update
- `maxUnavailable: 0` - Maintain full availability

This ensures zero-downtime deployments:

```bash
# Monitor rolling update
kubectl rollout status deployment/ems-backend -n dev --watch

# Check update history
kubectl rollout history deployment/ems-backend -n dev

# Rollback to previous version
kubectl rollout undo deployment/ems-backend -n dev
kubectl rollout undo deployment/ems-backend -n dev --to-revision=2
```

---

## Troubleshooting

### Issue: Pods Not Starting

```bash
# Check pod events
kubectl describe pod <pod-name> -n dev

# Check pod logs
kubectl logs <pod-name> -n dev

# Check init container logs (if using)
kubectl logs <pod-name> -c wait-for-db -n dev

# Common issues:
# 1. Image not found - verify image URL
# 2. Resources insufficient - check node capacity
# 3. Database not ready - check PostgreSQL connectivity
```

### Issue: Service Not Accessible

```bash
# Verify service exists
kubectl get svc -n dev

# Check service endpoints
kubectl get endpoints -n dev ems-frontend

# Test from pod
kubectl run -it --rm debug --image=busybox --restart=Never -n dev -- \
  sh -c 'wget -O - http://ems-frontend:80/'

# Check network policies
kubectl get networkpolicies -n dev
```

### Issue: Ingress Not Working

```bash
# Check ingress status
kubectl get ingress -n dev
kubectl describe ingress ems-ingress -n dev

# Check AGIC controller
kubectl get pods -n kube-system | grep ingress-azure
kubectl logs -n kube-system -l app=ingress-azure

# Check Application Gateway rules were created
az network application-gateway http-settings list \
  --gateway-name <gateway-name> \
  --resource-group <resource-group>

# Test backend health
curl -v http://<app-gateway-ip>/api/employees
```

### Issue: Database Connection Failed

```bash
# Check pod env variables
kubectl set env deployment/ems-backend --list -n dev

# Test database connectivity from pod
kubectl exec -it <backend-pod> -n dev -- \
  bash -c 'nc -zv postgres.dev.svc.cluster.local 5432'

# Check DNS resolution
kubectl exec -it <pod> -n dev -- \
  bash -c 'nslookup postgres.dev.svc.cluster.local'
```

### Clear All and Restart

```bash
# Delete all resources
kubectl delete -f k8s/ -n dev

# Or delete namespace (removes everything)
kubectl delete namespace dev

# Recreate from scratch
kubectl apply -f k8s/
```

---

## Production Checklist

### Security
- [ ] Non-root users configured (✓ Done)
- [ ] Security contexts enforced (✓ Done)
- [ ] RBAC roles assigned (✓ Done)
- [ ] Network policies configured (optional)
- [ ] Pod Security Policy enforced (optional)
- [ ] Secrets stored in Azure Key Vault (not in Secret objects)
- [ ] Container scanning enabled
- [ ] Image signing enabled

### High Availability
- [ ] Multiple replicas deployed (✓ minimum 2)
- [ ] Pod disruption budgets configured (✓ Done)
- [ ] Node affinity/anti-affinity configured (✓ Done)
- [ ] Readiness probes working (✓ Done)
- [ ] Liveness probes working (✓ Done)
- [ ] Load balancing configured via AGIC

### Performance
- [ ] Resource requests configured (✓ Done)
- [ ] Resource limits configured (✓ Done)
- [ ] Horizontal Pod Autoscaler (HPA) configured
- [ ] Cluster autoscaler enabled
- [ ] Network policies optimized
- [ ] Storage optimized (if using persistent volumes)

### Monitoring & Logging
- [ ] Container logs aggregated (AKS monitoring)
- [ ] Metrics collection enabled (Prometheus)
- [ ] Alerts configured
- [ ] Dashboard created (Grafana)
- [ ] Distributed tracing enabled (optional)

### Cost Optimization
- [ ] Node sizes right-sized
- [ ] Spot instances used (optional)
- [ ] Resource requests based on actual usage
- [ ] Unused resources cleaned up
- [ ] Pod density optimized

### Backup & Disaster Recovery
- [ ] Etcd backups configured
- [ ] Database backups automated
- [ ] Recovery procedure tested
- [ ] RTO/RPO defined

### Compliance
- [ ] RBAC policies audit-logged
- [ ] Network policies documented
- [ ] Secrets management documented
- [ ] Access logs retained
- [ ] Regulatory requirements met

---

## Useful Commands Reference

```bash
# Namespace operations
kubectl create namespace dev
kubectl delete namespace dev
kubectl get namespaces

# Pod operations
kubectl get pods -n dev
kubectl describe pod <pod-name> -n dev
kubectl logs pod/<pod-name> -n dev
kubectl exec -it <pod-name> -n dev -- bash
kubectl port-forward pod/<pod-name> 8080:8080 -n dev

# Deployment operations
kubectl get deployments -n dev
kubectl describe deployment ems-backend -n dev
kubectl scale deployment ems-backend --replicas=3 -n dev
kubectl set image deployment/ems-backend app=<image> -n dev
kubectl rollout status deployment/ems-backend -n dev
kubectl rollout undo deployment/ems-backend -n dev

# Service operations
kubectl get services -n dev
kubectl describe service ems-backend -n dev
kubectl get endpoints -n dev

# Configuration
kubectl get configmaps -n dev
kubectl get secrets -n dev
kubectl edit configmap ems-backend-config -n dev

# Ingress operations
kubectl get ingress -n dev
kubectl describe ingress ems-ingress -n dev

# Debugging
kubectl cluster-info
kubectl get nodes
kubectl describe node <node-name>
kubectl top nodes
kubectl top pods -n dev
```

---

**Version**: 1.0  
**Last Updated**: June 2024  
**Kubernetes Version**: 1.27+  
**AKS Version**: Latest  
**AGIC Version**: Latest
