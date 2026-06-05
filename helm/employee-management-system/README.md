# Employee Management System - Helm Chart

This Helm chart provides a complete, production-ready deployment for the 3-tier Employee Management System on Azure Kubernetes Service (AKS).

## Chart Information

- **Chart Name**: employee-management-system
- **Version**: 1.0.0
- **App Version**: 1.0.0
- **Type**: Application

## Features

✅ **Complete Application Stack**
- Spring Boot Backend (Java 17)
- React Frontend (Vite)
- PostgreSQL Database
- Nginx Ingress
- Horizontal Pod Autoscaling

✅ **Production-Ready**
- Health checks (liveness & readiness probes)
- Resource limits and requests
- Security contexts
- Network policies
- Pod disruption budgets

✅ **Environment Support**
- Development (dev)
- Quality Assurance (qa)  
- Production (prod)

✅ **Enterprise Features**
- HorizontalPodAutoscaler (HPA)
- Service to service communication
- Database migrations support
- Configurable image registries
- Multi-environment values files

## Quick Start

### Prerequisites

- Kubernetes 1.27+
- Helm 3.12+
- kubectl configured
- Azure Container Registry (ACR) access

### Installation

```bash
# Add Helm repository
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# Install chart (development)
helm install employee-management-system . \
  --namespace employee-management \
  --create-namespace \
  --values values.yaml \
  --values values-dev.yaml

# Install chart (production)
helm install employee-management-system . \
  --namespace employee-management \
  --create-namespace \
  --values values.yaml \
  --values values-prod.yaml \
  --set global.tls.enabled=true
```

## Chart Structure

```
employee-management-system/
├── Chart.yaml                    # Chart metadata
├── values.yaml                   # Default values
├── values-dev.yaml               # Development overrides
├── values-prod.yaml              # Production overrides
└── templates/
    ├── _helpers.tpl              # Helper functions
    ├── NOTES.txt                 # Post-install notes
    ├── namespace.yaml            # Kubernetes namespace
    ├── deployment-backend.yaml   # Backend Spring Boot deployment
    ├── deployment-frontend.yaml  # Frontend React deployment
    ├── service-backend.yaml      # Backend service
    ├── service-frontend.yaml     # Frontend service
    ├── ingress.yaml              # Ingress configuration
    ├── configmap.yaml            # Backend configuration
    ├── secret.yaml               # Database credentials
    └── hpa.yaml                  # Horizontal Pod Autoscaler
```

## Configuration

### Global Settings

```yaml
global:
  environment: dev|qa|prod        # Deployment environment
  domain: example.com              # Domain name
  tls:
    enabled: true                  # Enable TLS/HTTPS
    issuer: letsencrypt-prod       # Cert manager issuer
```

### Backend Configuration

```yaml
backend:
  enabled: true
  replicaCount: 2                  # Number of replicas
  image:
    repository: acr.azurecr.io/ems-backend
    tag: latest
    pullPolicy: IfNotPresent
  
  service:
    type: ClusterIP                # Service type
    port: 8080
  
  resources:
    requests:
      cpu: 500m
      memory: 512Mi
    limits:
      cpu: 1000m
      memory: 1Gi
  
  autoscaling:
    enabled: true
    minReplicas: 2
    maxReplicas: 5
    targetCPUUtilizationPercentage: 75
```

### Frontend Configuration

```yaml
frontend:
  enabled: true
  replicaCount: 2
  image:
    repository: acr.azurecr.io/ems-frontend
    tag: latest
    pullPolicy: IfNotPresent
  
  service:
    type: LoadBalancer              # Service type
    port: 80
  
  ingress:
    enabled: true
    className: nginx
    hosts:
      - host: app.example.com
        paths:
          - path: /
            pathType: Prefix
```

### Database Configuration

```yaml
postgresql:
  enabled: true
  auth:
    username: employee_user
    password: ChangeMe123!
    database: employee_db
  
  primary:
    persistence:
      enabled: true
      size: 10Gi
      storageClassName: managed-premium
```

## Usage Examples

### Install with Custom Values

```bash
helm install employee-management-system . \
  --namespace production \
  --set global.environment=prod \
  --set backend.replicaCount=3 \
  --set frontend.replicaCount=3 \
  --set registry.name=myacr.azurecr.io \
  --set postgresql.auth.password=SecurePassword123!
```

### Upgrade Release

```bash
helm upgrade employee-management-system . \
  --namespace employee-management \
  --values values-prod.yaml \
  --set backend.image.tag=v2.0.0 \
  --set frontend.image.tag=v2.0.0 \
  --wait
```

### Dry-Run Deployment

```bash
helm install employee-management-system . \
  --namespace employee-management \
  --create-namespace \
  --dry-run \
  --debug
```

### View Generated Manifests

```bash
helm template employee-management-system . \
  --namespace employee-management \
  --values values-dev.yaml > manifests.yaml
```

### Rollback to Previous Version

```bash
helm rollback employee-management-system \
  --namespace employee-management
```

### View Release History

```bash
helm history employee-management-system \
  --namespace employee-management
```

## Parameters

### Global Parameters
| Parameter | Description | Default |
|-----------|-------------|---------|
| `global.environment` | Deployment environment (dev/qa/prod) | `dev` |
| `global.domain` | Domain name | `example.com` |
| `global.tls.enabled` | Enable TLS | `true` |

### Registry Parameters
| Parameter | Description | Default |
|-----------|-------------|---------|
| `registry.name` | Container registry hostname | `acr.azurecr.io` |
| `registry.username` | Registry username | `` |
| `registry.password` | Registry password | `` |

### Backend Parameters
| Parameter | Description | Default |
|-----------|-------------|---------|
| `backend.enabled` | Enable backend deployment | `true` |
| `backend.replicaCount` | Number of replicas | `2` |
| `backend.image.repository` | Image repository | `acr.azurecr.io/ems-backend` |
| `backend.image.tag` | Image tag | `latest` |
| `backend.resources.requests.cpu` | CPU request | `500m` |
| `backend.resources.requests.memory` | Memory request | `512Mi` |
| `backend.autoscaling.enabled` | Enable HPA | `true` |
| `backend.autoscaling.minReplicas` | Min replicas | `2` |
| `backend.autoscaling.maxReplicas` | Max replicas | `5` |

### Frontend Parameters
| Parameter | Description | Default |
|-----------|-------------|---------|
| `frontend.enabled` | Enable frontend deployment | `true` |
| `frontend.replicaCount` | Number of replicas | `2` |
| `frontend.image.repository` | Image repository | `acr.azurecr.io/ems-frontend` |
| `frontend.image.tag` | Image tag | `latest` |
| `frontend.ingress.enabled` | Enable ingress | `true` |

### PostgreSQL Parameters
| Parameter | Description | Default |
|-----------|-------------|---------|
| `postgresql.enabled` | Enable PostgreSQL | `true` |
| `postgresql.auth.username` | DB username | `employee_user` |
| `postgresql.auth.password` | DB password | `ChangeMe123!` |
| `postgresql.auth.database` | DB name | `employee_db` |
| `postgresql.primary.persistence.size` | PVC size | `10Gi` |

## Monitoring

### Check Deployment Status

```bash
# Get all resources
kubectl get all -n employee-management

# Check specific deployment
kubectl describe deployment ems-backend -n employee-management

# View pod logs
kubectl logs -n employee-management -l app.kubernetes.io/component=backend -f

# Watch scaling behavior
kubectl get hpa -n employee-management --watch
```

## Troubleshooting

### Pods in Pending State

```bash
# Check events
kubectl describe pod <pod-name> -n employee-management

# Check resource availability
kubectl describe nodes

# Check PVC status
kubectl get pvc -n employee-management
```

### ImagePullBackOff

```bash
# Verify image exists in registry
az acr repository show --name myacr --repository ems-backend

# Check image pull secret
kubectl get secret acr-secret -n employee-management -o yaml
```

### CrashLoopBackOff

```bash
# Check logs from previous run
kubectl logs <pod-name> -n employee-management --previous

# Describe pod for error details
kubectl describe pod <pod-name> -n employee-management
```

### Database Connection Issues

```bash
# Check database pod
kubectl get pods -n employee-management -l app.kubernetes.io/name=postgresql

# Test database connectivity
kubectl exec <db-pod> -n employee-management -- \
  psql -U employee_user -d employee_db -c "SELECT 1;"
```

## Best Practices

### 1. Security
- [ ] Change PostgreSQL password from default
- [ ] Use separate image pull secrets
- [ ] Enable network policies
- [ ] Use managed identities for Azure access
- [ ] Enable pod security policies

### 2. Performance
- [ ] Set appropriate resource requests/limits
- [ ] Enable HPA for auto-scaling
- [ ] Use persistent volumes for databases
- [ ] Configure probes appropriately
- [ ] Monitor resource usage regularly

### 3. High Availability
- [ ] Deploy at least 2 replicas
- [ ] Use pod anti-affinity
- [ ] Enable zone redundancy
- [ ] Setup health checks
- [ ] Configure rolling updates

### 4. Observability
- [ ] Enable application metrics
- [ ] Setup centralized logging
- [ ] Monitor resource usage
- [ ] Track deployment changes
- [ ] Setup alerting

## Maintenance

### Regular Tasks
- Monthly: Review and rotate secrets
- Weekly: Check resource utilization
- Monthly: Verify backup status
- Quarterly: Test disaster recovery
- On each release: Verify application functionality

## Contributing

To modify the chart:

1. Update `Chart.yaml` for version changes
2. Modify relevant template files
3. Test with dry-run: `helm template`
4. Test installation in dev environment
5. Document changes in CHANGELOG

## License

[Add your license here]

## Support

For issues or questions:
- Check documentation in `/docs`
- Review logs: `kubectl logs -n employee-management`
- Check events: `kubectl get events -n employee-management`
- Contact DevOps team

## Related Documentation

- [Deployment Guide](../docs/DEPLOYMENT_GUIDE.md)
- [Rollback Strategy](../docs/ROLLBACK_STRATEGY.md)
- [GitHub Actions Workflows](../.github/workflows)
- [Terraform Infrastructure](../terraform)
