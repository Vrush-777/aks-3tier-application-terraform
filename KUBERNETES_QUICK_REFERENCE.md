# Kubernetes Quick Reference - EMS Application

## 📁 Directory Structure

```
k8s/
├── namespace/
│   └── namespace.yaml              # ✅ dev namespace
├── frontend/
│   ├── deployment.yaml             # ✅ Nginx deployment + PDB + security
│   └── service.yaml                # ✅ ClusterIP service + RBAC
├── backend/
│   ├── deployment.yaml             # ✅ Spring Boot + init container + JVM tuning
│   ├── service.yaml                # ✅ ClusterIP service + RBAC
│   ├── configmap.yaml              # ✅ Non-sensitive configuration
│   └── secret.yaml                 # ✅ Database password (use Key Vault in prod)
└── ingress/
    └── ingress.yaml                # ✅ AGIC ingress controller

Total: 9 YAML files, fully production-ready with comprehensive comments
```

---

## 🚀 Quick Deploy (5 Steps)

### 1. Update Image References
Edit image URLs in deployment files:
```yaml
image: <your-registry>.azurecr.io/ems-frontend:latest
image: <your-registry>.azurecr.io/ems-backend:latest
```

### 2. Get AKS Credentials
```bash
az aks get-credentials --resource-group <rg> --name <cluster>
```

### 3. Deploy All Resources
```bash
# Create namespace
kubectl apply -f k8s/namespace/

# Deploy backend (needs config + secrets first)
kubectl apply -f k8s/backend/

# Deploy frontend
kubectl apply -f k8s/frontend/

# Deploy ingress (AGIC)
kubectl apply -f k8s/ingress/
```

### 4. Wait for Deployment
```bash
kubectl rollout status deployment/ems-frontend -n dev --timeout=300s
kubectl rollout status deployment/ems-backend -n dev --timeout=300s
```

### 5. Get Public IP
```bash
# From Application Gateway
az network public-ip show --name <pip-name> --resource-group <rg> --query ipAddress
```

---

## 📊 Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                  Azure Kubernetes Service (AKS)            │
│  ┌──────────────────────────────────────────────────────┐  │
│  │                    dev namespace                     │  │
│  │                                                      │  │
│  │  ┌──────────────────────┐   ┌──────────────────┐   │  │
│  │  │  Frontend Deployment │   │ Backend Deployment   │  │
│  │  │  (ems-frontend)      │   │ (ems-backend)        │  │
│  │  │                      │   │                      │  │
│  │  │  Pods:               │   │  Pods:               │  │
│  │  │  - Nginx x2 (2 CPU:  │   │  - Spring Boot x2 (4 │  │
│  │  │    0.5 limit)        │   │    CPU: 1 limit)     │  │
│  │  │  - 256Mi mem         │   │  - 1Gi mem           │  │
│  │  │                      │   │  - Init: wait-db     │  │
│  │  │  Service:            │   │                      │  │
│  │  │  ClusterIP :80       │   │  Service:            │  │
│  │  │                      │   │  ClusterIP :8080     │  │
│  │  └──────────────────────┘   └──────────────────────┘  │
│  │           ▲                          ▲                  │
│  │           │                          │                  │
│  │           └──────────────┬───────────┘                  │
│  │                          │                              │
│  │                    ┌─────▼────────┐                     │
│  │                    │   Ingress    │                     │
│  │                    │  (AGIC)      │                     │
│  │                    │              │                     │
│  │                    │  /    → :80  │                     │
│  │                    │  /api → :8080│                     │
│  │                    └─────┬────────┘                     │
│  └─────────────────────────┼─────────────────────────────┘ │
│                            │                                │
└────────────────────────────┼────────────────────────────────┘
                             │
                    ┌────────▼─────────┐
                    │ Application      │
                    │ Gateway (AGIC)   │
                    │ Public IP: ...   │
                    └──────────────────┘
                             │
                    ┌────────▼─────────┐
                    │    Internet      │
                    │   Clients        │
                    └──────────────────┘
```

---

## 🔧 Common Commands

### Deploy & Update
```bash
# Deploy all
kubectl apply -f k8s/

# Deploy namespace only
kubectl apply -f k8s/namespace/

# Deploy specific component
kubectl apply -f k8s/frontend/deployment.yaml -n dev

# Redeploy (forces update)
kubectl rollout restart deployment/ems-backend -n dev
```

### View Status
```bash
# All pods
kubectl get pods -n dev

# All services
kubectl get svc -n dev

# Ingress
kubectl get ingress -n dev

# Detailed pod info
kubectl describe pod <pod-name> -n dev
```

### Logs
```bash
# Frontend logs
kubectl logs -f deployment/ems-frontend -n dev

# Backend logs
kubectl logs -f deployment/ems-backend -n dev

# Previous logs (if crashed)
kubectl logs <pod-name> -n dev --previous
```

### Execute Commands
```bash
# Connect to pod
kubectl exec -it <pod-name> -n dev -- bash

# Test connectivity
kubectl run -it --rm test --image=busybox --restart=Never -- \
  wget -O - http://ems-backend:8080/api/employees
```

### Scale
```bash
# Scale to 3 replicas
kubectl scale deployment ems-backend --replicas=3 -n dev

# Auto-scale
kubectl autoscale deployment ems-backend --min=2 --max=10 --cpu-percent=70 -n dev
```

### Update Configuration
```bash
# Edit ConfigMap
kubectl edit configmap ems-backend-config -n dev

# Edit Secret
kubectl set env secret/ems-backend-secrets DB_[REDACTED_GENERIC_PASSWORD_1]=newpass -n dev

# Restart to pick up changes
kubectl rollout restart deployment/ems-backend -n dev
```

### Troubleshoot
```bash
# Check events
kubectl get events -n dev --sort-by='.lastTimestamp'

# Check logs
kubectl logs <pod-name> -n dev

# Describe pod for errors
kubectl describe pod <pod-name> -n dev

# Check resource usage
kubectl top pods -n dev

# Test service connectivity
kubectl run -it --rm debug --image=busybox --restart=Never -- \
  nslookup ems-backend.dev.svc.cluster.local
```

### Cleanup
```bash
# Delete all resources
kubectl delete -f k8s/ -n dev

# Delete namespace (removes everything)
kubectl delete namespace dev

# Delete specific deployment
kubectl delete deployment ems-backend -n dev
```

---

## ✅ Verification Checklist

### Before Deployment
- [ ] Container images built and pushed to registry
- [ ] Image URLs updated in deployment files
- [ ] AKS cluster accessible (`kubectl cluster-info`)
- [ ] AGIC controller installed (`kubectl get pods -n kube-system | grep ingress-azure`)
- [ ] Application Gateway created and configured

### After Deployment
- [ ] Namespace created: `kubectl get ns`
- [ ] Pods running: `kubectl get pods -n dev`
- [ ] Services created: `kubectl get svc -n dev`
- [ ] Ingress created: `kubectl get ingress -n dev`
- [ ] Pods healthy: `kubectl get pods -n dev -o wide` (all "Running")
- [ ] No pod errors: `kubectl describe pod <pod> -n dev`

### Functionality Tests
- [ ] Frontend accessible: `curl http://<ip>/`
- [ ] Backend API accessible: `curl http://<ip>/api/employees`
- [ ] Health check: `curl http://<ip>/actuator/health`
- [ ] Database connectivity verified in pod logs

---

## 📋 Resource Allocation Summary

| Component | Replicas | CPU Req | CPU Limit | Mem Req | Mem Limit |
|-----------|----------|---------|-----------|---------|-----------|
| Frontend  | 2        | 100m    | 500m      | 128Mi   | 256Mi     |
| Backend   | 2        | 250m    | 1000m     | 512Mi   | 1024Mi    |
| **Total** | **4**    | **700m**| **3000m** | **1.25Gi** | **2.5Gi** |

**Cluster Requirements:**
- Minimum: 3 nodes (D2s_v3 = 2 CPU, 8GB RAM each)
- Recommended: 4+ nodes for production
- Total capacity should be > 3x pod resource limits

---

## 🔐 Security Features

| Feature | Implementation | Status |
|---------|---|--------|
| Non-root user | runAsUser: 33 (frontend), 1000 (backend) | ✅ Enabled |
| Security context | Drop all capabilities, no privilege escalation | ✅ Enabled |
| RBAC | Service accounts + Roles + RoleBindings | ✅ Enabled |
| Network policies | Can be enabled (optional) | ⏳ Optional |
| Pod security policies | Can be enforced (optional) | ⏳ Optional |
| Secrets encryption | Use Azure Key Vault (not base64 only) | ⏳ Recommended |
| Image scanning | Enable in ACR | ⏳ Recommended |
| Network segmentation | Via Service Mesh (optional) | ⏳ Optional |

---

## 📈 Scaling Configuration

### Manual Scaling
```bash
kubectl scale deployment ems-backend --replicas=5 -n dev
```

### Horizontal Pod Autoscaler (HPA)
```bash
kubectl autoscale deployment ems-backend \
  --min=2 \
  --max=10 \
  --cpu-percent=70 \
  -n dev

# View HPA status
kubectl get hpa -n dev
```

### Manual HPA (advanced)
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: ems-backend-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: ems-backend
  minReplicas: 2
  maxReplicas: 10
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
```

---

## 🔄 Rolling Update Process

### How It Works
```
Initial State:        Update Started:       Update In Progress:     Complete:
┌─────────────┐       ┌─────────────┐       ┌─────────────┐        ┌─────────────┐
│ Pod 1 (v1)  │       │ Pod 1 (v1)  │       │ Pod 1 (v1)  │        │ Pod 1 (v2)  │
│ Pod 2 (v1)  │  -->  │ Pod 2 (v1)  │  -->  │ Pod 2 (v2)  │   -->  │ Pod 2 (v2)  │
└─────────────┘       │ Pod 3 (v2)  │       └─────────────┘        └─────────────┘
                      └─────────────┘       (healthcheck pass)
                      (start new)           (remove old)
```

### Perform Update
```bash
# Update image
kubectl set image deployment/ems-backend \
  spring-boot=registry/ems-backend:v1.1 \
  -n dev

# Monitor progress
kubectl rollout status deployment/ems-backend -n dev --watch

# Rollback if needed
kubectl rollout undo deployment/ems-backend -n dev
```

---

## 🚨 Troubleshooting Quick Guide

| Problem | Diagnosis | Solution |
|---------|-----------|----------|
| Pods not starting | `kubectl describe pod <pod>` | Check image exists, resources available |
| Service not accessible | `kubectl get endpoints <svc>` | Verify pod IP in endpoints |
| Ingress not working | Check AGIC logs: `kubectl logs -n kube-system -l app=ingress-azure` | Verify AGIC installed, ingress class correct |
| Database connection error | Pod logs: `kubectl logs <pod>` | Check DB_HOST, DB_[REDACTED_GENERIC_PASSWORD_1], network |
| Out of memory (OOM) | Check resource limits: `kubectl get pod <pod> -o yaml` | Increase memory limit, reduce replicas |
| High CPU usage | Monitor: `kubectl top pod` | Scale horizontally with HPA |
| Pod stuck pending | `kubectl describe pod <pod>` | Check node resources, taints, tolerations |

---

## 📚 Additional Resources

### YAML Files Reference
- **namespace.yaml**: Kubernetes logical boundary
- **frontend/deployment.yaml**: Nginx app deployment with rolling updates
- **frontend/service.yaml**: Internal DNS for frontend pods
- **backend/deployment.yaml**: Spring Boot app with JVM optimization
- **backend/service.yaml**: Internal DNS for backend pods
- **backend/configmap.yaml**: Non-sensitive configuration
- **backend/secret.yaml**: Database credentials
- **ingress/ingress.yaml**: AGIC-based external routing

### Documentation Files
- **KUBERNETES_DEPLOYMENT_GUIDE.md**: Complete setup and operations
- **KUBERNETES_CONFIGURATION_STRATEGY.md**: Design decisions and best practices
- **DOCKER_GUIDE.md**: Docker Compose reference (for local testing)

### External Resources
- [Kubernetes Official Docs](https://kubernetes.io/docs/)
- [AKS Documentation](https://learn.microsoft.com/en-us/azure/aks/)
- [AGIC Documentation](https://learn.microsoft.com/en-us/azure/application-gateway/ingress-controller-overview)
- [Spring Boot on Kubernetes](https://spring.io/guides/topicals/spring-boot-docker/)

---

## 🎯 Success Criteria

✅ **Deployment is successful when:**
1. All 4 pods running in dev namespace
2. All services have valid cluster IPs
3. Ingress shows Application Gateway IP
4. Frontend accessible at `http://<ip>/`
5. Backend API accessible at `http://<ip>/api/employees`
6. Health checks passing
7. No pod restart loops
8. Appropriate resource usage (not over-allocated)

---

**Last Updated**: June 2024  
**Version**: 1.0  
**Kubernetes Version**: 1.27+  
**Status**: Production Ready ✅
