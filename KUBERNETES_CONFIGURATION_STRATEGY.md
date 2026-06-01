# Kubernetes Configuration Strategy & Best Practices

## Overview

This document outlines the configuration strategy for deploying the EMS application on Kubernetes with focus on:
- Configuration organization and management
- Security best practices
- Scalability and reliability
- Production readiness

---

## 1. Namespace Strategy

### Purpose
Namespaces provide logical isolation within a cluster:

```yaml
metadata:
  namespace: dev
  labels:
    environment: development
```

### Multi-Environment Setup
```
Cluster
├── dev namespace       # Development environment
├── qa namespace        # QA/Staging environment
└── prod namespace      # Production environment
```

### Benefits
- Resource isolation per environment
- Independent RBAC policies
- Separate quotas and limits
- Easy cleanup (delete namespace = delete all resources)

### Implementation
```bash
# Create namespaces
kubectl create namespace dev
kubectl create namespace qa
kubectl create namespace prod

# Deploy to specific namespace
kubectl apply -f k8s/ -n dev
kubectl apply -f k8s/ -n prod
```

---

## 2. Deployment Configuration

### Frontend Deployment

#### Key Features
```yaml
replicas: 2                           # HA across nodes
strategy:
  type: RollingUpdate                 # Zero-downtime updates
  rollingUpdate:
    maxSurge: 1                       # 1 extra pod during update
    maxUnavailable: 0                 # Never lose availability
```

#### Resource Management
```yaml
resources:
  requests:
    cpu: 100m           # Minimum guaranteed
    memory: 128Mi       # 128MB minimum
  limits:
    cpu: 500m           # Cap at 500m = 0.5 CPU cores
    memory: 256Mi       # Cap at 256MB
```

**Rationale:**
- Requests ensure pod gets scheduled with resources available
- Limits prevent runaway processes from affecting cluster
- Frontend is lightweight (Nginx + static assets)

#### Health Probes

**Readiness Probe** (when to send traffic):
```yaml
readinessProbe:
  httpGet:
    path: /health
    port: 80
  initialDelaySeconds: 5      # Wait for pod to start
  periodSeconds: 10           # Check every 10 seconds
  failureThreshold: 3         # 3 failures = not ready
```

**Liveness Probe** (when to restart):
```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 80
  initialDelaySeconds: 15     # Give more time
  periodSeconds: 20           # Check less frequently
  failureThreshold: 3         # 3 failures = restart
```

#### Security Context
```yaml
securityContext:
  runAsNonRoot: true          # Must run as non-root
  runAsUser: 33               # nginx user ID
  allowPrivilegeEscalation: false
  capabilities:
    drop:
      - ALL                   # No special capabilities
```

### Backend Deployment

#### Key Differences from Frontend
```yaml
replicas: 2                           # Same HA approach
initialDelaySeconds: 30               # Longer for JVM startup
startupProbe:                         # For slow-starting apps
  periodSeconds: 5
  failureThreshold: 30                # 150 seconds total
```

#### Resource Allocation for JVM
```yaml
resources:
  requests:
    memory: 512Mi          # JVM needs ~100MB base + heap
  limits:
    memory: 1024Mi         # Allow up to 1GB
```

#### Init Container
```yaml
initContainers:
  - name: wait-for-db
    image: busybox:1.35
    command: ['sh', '-c', 'until nc -z postgres 5432; do echo waiting; sleep 2; done']
```

**Purpose:** Ensures database is ready before app starts

#### JVM Memory Optimization
```yaml
env:
  - name: JAVA_TOOL_OPTIONS
    value: "-XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0"
```

**Explanation:**
- `UseContainerSupport`: Respects Kubernetes memory limits
- `MaxRAMPercentage=75.0`: Use 75% of container limit for heap
- Prevents OOMKilled errors

---

## 3. Service Configuration

### Frontend Service
```yaml
apiVersion: v1
kind: Service
metadata:
  name: ems-frontend
spec:
  type: ClusterIP        # Internal only (AGIC provides external access)
  selector:
    app: ems-frontend
  ports:
    - name: http
      port: 80
      targetPort: 80
```

### Backend Service
```yaml
apiVersion: v1
kind: Service
metadata:
  name: ems-backend
spec:
  type: ClusterIP        # Internal only
  selector:
    app: ems-backend
  ports:
    - name: http
      port: 8080
      targetPort: 8080
```

### Service Discovery
- Frontend finds backend via: `http://ems-backend.dev.svc.cluster.local:8080`
- Backend finds database via: `postgres.dev.svc.cluster.local:5432`
- DNS is automatic within cluster

---

## 4. Configuration Management

### ConfigMap Strategy
**Store in ConfigMap:**
- Non-sensitive configuration
- Environment-specific settings
- Log levels, feature flags
- Database connection parameters (host, port, but NOT password)

```yaml
data:
  DB_HOST: postgres.dev.svc.cluster.local
  DB_PORT: "5432"
  DB_NAME: employee_dev
  SPRING_PROFILES_ACTIVE: "dev"
  LOG_LEVEL: "INFO"
```

**Update Strategy:**
```bash
# 1. Edit ConfigMap
kubectl edit configmap ems-backend-config -n dev

# 2. Restart deployment to pick up changes
kubectl rollout restart deployment/ems-backend -n dev

# 3. Verify
kubectl rollout status deployment/ems-backend -n dev
```

### Secret Strategy
**Store in Secret:**
- Passwords, API keys, tokens
- Database credentials
- SSL/TLS certificates
- OAuth secrets

```yaml
stringData:
  DB_[REDACTED_GENERIC_PASSWORD_1]: "your-secure-password"
```

**Security Considerations:**
⚠️ **Warning:** Kubernetes Secrets are base64-encoded (NOT encrypted by default)

**Production Solution:** Use Azure Key Vault with Workload Identity:

```yaml
# External Secrets Operator (ESO)
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: azure-keyvault
spec:
  provider:
    azure:
      auth:
        workloadIdentity:
          serviceAccountRef:
            name: ems-backend
      vaultUrl: "https://vault-name.vault.azure.net"
```

---

## 5. AGIC Ingress Configuration

### Ingress vs Service
```
Traditional LoadBalancer Service:
- Each service gets separate IP
- Expensive (multiple load balancers)
- Limited routing capabilities

AGIC Ingress:
- Single entry point (Application Gateway)
- URL-based routing (/api → backend, / → frontend)
- Cost-effective
- Centralized SSL/TLS
```

### Routing Rules
```yaml
rules:
  - http:
      paths:
        - path: /api
          backend:
            service:
              name: ems-backend
              port:
                number: 8080
        
        - path: /
          backend:
            service:
              name: ems-frontend
              port:
                number: 80
```

### AGIC Annotations
```yaml
metadata:
  annotations:
    kubernetes.io/ingress.class: azure/application-gateway
    appgw.ingress.kubernetes.io/backend-protocol: "http"
    appgw.ingress.kubernetes.io/health-probe-path: "/"
    appgw.ingress.kubernetes.io/request-timeout: "60"
```

---

## 6. RBAC (Role-Based Access Control)

### Why RBAC?
Security principle: **Least Privilege**

Each pod should only have permissions it needs:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: ems-backend
rules:
  - apiGroups: [""]
    resources: ["configmaps", "secrets"]
    verbs: ["get"]
```

### Service Account Binding
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ems-backend

---

apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: ems-backend
roleRef:
  kind: Role
  name: ems-backend
subjects:
  - kind: ServiceAccount
    name: ems-backend
```

---

## 7. Pod Disruption Budget (PDB)

### Purpose
Protects availability during:
- Cluster upgrades
- Node drains
- Maintenance

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: ems-backend-pdb
spec:
  minAvailable: 1              # At least 1 pod must always be running
  selector:
    matchLabels:
      app: ems-backend
```

### Impact
- Prevents all pods from being evicted at once
- Ensures service remains available during cluster operations
- Critical for production

---

## 8. Scaling Strategy

### Horizontal Pod Autoscaler (HPA)

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

**How it works:**
- Monitors CPU and memory usage
- Automatically adds replicas if usage > 70% CPU or 80% memory
- Scales down when usage drops
- Respects min/max replica limits

### Manual Scaling
```bash
# Scale to 5 replicas
kubectl scale deployment ems-backend --replicas=5 -n dev

# Auto-scaling
kubectl autoscale deployment ems-backend \
  --min=2 --max=10 \
  --cpu-percent=70 \
  -n dev
```

---

## 9. Update Strategy

### Rolling Updates (Zero Downtime)
```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 1              # Allow 1 extra pod
    maxUnavailable: 0        # Never reduce availability
```

**Sequence:**
1. Start new pod (now 3 pods total: 2 old + 1 new)
2. Wait for new pod to be healthy
3. Remove old pod (back to 2 pods)
4. Repeat for each pod

**Result:** Service never goes down

### Update Process
```bash
# Update image
kubectl set image deployment/ems-backend \
  spring-boot=registry.azurecr.io/ems-backend:v1.1 \
  -n dev

# Monitor update
kubectl rollout status deployment/ems-backend -n dev --watch

# Rollback if needed
kubectl rollout undo deployment/ems-backend -n dev
```

---

## 10. Environment-Specific Configurations

### Development (dev namespace)
```yaml
replicas: 1                    # Single replica OK for dev
resources:
  limits:
    memory: 512Mi
LOG_LEVEL: DEBUG              # Verbose logging
```

### Staging/QA (qa namespace)
```yaml
replicas: 2                    # Multiple replicas for testing
resources:
  limits:
    memory: 1024Mi
LOG_LEVEL: INFO
```

### Production (prod namespace)
```yaml
replicas: 3                    # High availability
resources:
  limits:
    memory: 2048Mi
LOG_LEVEL: WARN               # Less logging, better performance
HPA:
  minReplicas: 3
  maxReplicas: 50
```

---

## 11. Security Best Practices

### Pod Security Standards
```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities:
    drop:
      - ALL
```

### Network Policies
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: dev-network-policy
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
  ingress:
    - from:
        - podSelector: {}
  egress:
    - to:
        - podSelector: {}
    - to:
        - namespaceSelector: {}
      ports:
        - protocol: TCP
          port: 443  # Allow HTTPS outbound
```

### Secrets Management
**Development:** Base64-encoded Kubernetes Secrets (current setup)

**Production:** Azure Key Vault with External Secrets Operator
```bash
# Install External Secrets Operator
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets external-secrets/external-secrets -n external-secrets-system --create-namespace

# Configure SecretStore pointing to Azure Key Vault
# Use Workload Identity for authentication (no credentials stored)
```

---

## 12. Observability & Monitoring

### Metrics Export
```yaml
metadata:
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "8080"
    prometheus.io/path: "/actuator/prometheus"
```

### Health Probes Endpoints
- Frontend: `http://localhost/health`
- Backend: `http://localhost:8080/actuator/health`
- Backend liveness: `http://localhost:8080/actuator/health/liveness`
- Backend readiness: `http://localhost:8080/actuator/health/readiness`

### Logging
```bash
# Real-time logs
kubectl logs -f deployment/ems-backend -n dev

# Aggregate logs
# Configure Azure Monitor or ELK Stack
```

---

## 13. Cost Optimization

### Resource Requests (Important!)
```yaml
resources:
  requests:
    cpu: 100m               # Tell scheduler what we need
    memory: 128Mi
  limits:
    cpu: 500m               # Hard limit
    memory: 256Mi
```

**Impact:**
- Accurate requests → better scheduling → lower costs
- Too low requests → OOM kills, crashes
- Too high limits → wasted resources

### Cost Saving Strategies
1. **Right-size requests and limits** (not too high, not too low)
2. **Use spot instances** for non-critical workloads
3. **Enable HPA** to scale down during low traffic
4. **Use AKS Uptime SLA** for production clusters
5. **Monitor actual usage** and adjust accordingly

---

## 14. Configuration Validation

### Pre-deployment Checks
```bash
# Validate YAML syntax
kubectl apply -f k8s/ --dry-run=client

# Check resource availability
kubectl api-resources

# Verify RBAC permissions
kubectl auth can-i create deployments --as=system:serviceaccount:dev:ems-backend -n dev
```

### Post-deployment Checks
```bash
# Verify pods are healthy
kubectl get pods -n dev -o wide

# Check resource usage
kubectl top pods -n dev

# View events for issues
kubectl get events -n dev --sort-by='.lastTimestamp'
```

---

## 15. Disaster Recovery

### Backup Strategy
```bash
# Backup current configuration
kubectl get all -n dev -o yaml > dev-backup.yaml

# Backup specific resource
kubectl get deployment ems-backend -n dev -o yaml > backend-deployment.yaml
```

### Restore Procedure
```bash
# Restore from backup
kubectl apply -f dev-backup.yaml

# Or restore individual resources
kubectl apply -f backend-deployment.yaml
```

### Etcd Backup (Cluster-level)
```bash
# Backup etcd database
az aks command invoke \
  --resource-group <rg> \
  --name <cluster> \
  --command "etcdctl snapshot save /tmp/etcd-backup.db"
```

---

## Summary Table

| Component | Configuration | Strategy |
|-----------|---------------|----------|
| **Namespace** | dev | Environment isolation |
| **Deployment** | Rolling Update | Zero-downtime updates |
| **Replicas** | 2+ | High availability |
| **Health Probes** | Readiness + Liveness | Auto-recovery |
| **Resources** | Requests + Limits | Predictable usage |
| **Config** | ConfigMap + Secret | Separation of concerns |
| **Service** | ClusterIP | Internal communication |
| **Ingress** | AGIC | External routing |
| **RBAC** | Role + RoleBinding | Security/least privilege |
| **PDB** | minAvailable: 1 | Availability during maintenance |
| **Scaling** | HPA | Auto-scaling based on metrics |
| **Security** | Non-root + Capabilities drop | Defense in depth |

---

**Version**: 1.0  
**Last Updated**: June 2024  
**Target Audience**: DevOps Engineers, Platform Engineers, SREs
