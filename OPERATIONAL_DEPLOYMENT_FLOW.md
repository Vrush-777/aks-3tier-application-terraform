# Operational Deployment Flow Document
## End-to-End CI/CD Pipeline for Private AKS Deployment

**Document Version:** 1.0  
**Last Updated:** June 2026  
**Classification:** Internal - Operations  
**Audience:** DevOps Engineers, Release Managers, SREs, Platform Engineers

---

## Table of Contents

1. [Executive Overview](#executive-overview)
2. [Deployment Pipeline Architecture](#deployment-pipeline-architecture)
3. [Stage-by-Stage Detailed Breakdown](#stage-by-stage-detailed-breakdown)
4. [Security Architecture](#security-architecture)
5. [Error Handling & Recovery](#error-handling--recovery)
6. [Cleanup Mechanisms](#cleanup-mechanisms)
7. [Deployment Verification](#deployment-verification)
8. [Azure RBAC Requirements](#azure-rbac-requirements)
9. [GitHub Secrets Configuration](#github-secrets-configuration)
10. [JumpVM Interaction Model](#jumpvm-interaction-model)
11. [Technology Decision Rationale](#technology-decision-rationale)
12. [Troubleshooting Guide](#troubleshooting-guide)
13. [Operational Runbooks](#operational-runbooks)

---

## Executive Overview

The deployment pipeline automates the complete journey from developer code commit to running application in a **private Azure Kubernetes Service (AKS) cluster**. The pipeline is designed with security, auditability, and reliability as first-class concerns.

### Key Design Principles

| Principle | Implementation |
|-----------|-----------------|
| **Zero-Trust Network** | Private AKS, JumpVM bastion access, managed identities |
| **Principle of Least Privilege** | Fine-grained RBAC, service principal-less authentication |
| **Infrastructure Immutability** | Docker multi-stage builds, Helm chart versioning |
| **Automated Verification** | Deployment checks, health probes, smoke tests |
| **Auditability** | All operations logged, Git commit traceability, Helm versioning |
| **Fail-Safe Design** | Rollback capability, deployment verification gates |

### Deployment Flow Duration

```
Typical Timeline:
├─ Developer Commit                           → 0:00 (Immediate)
├─ GitHub Actions Trigger                     → 0:01
├─ Change Detection                           → 0:02
├─ Backend Build (Maven, 2-3 minutes)         → 2:30
├─ Frontend Build (Npm, 1-2 minutes parallel) → 2:30
├─ Docker Image Creation & Push               → 3:30
├─ Helm Chart Package & Upload                → 4:00
├─ JumpVM Download & Deploy                   → 5:30
├─ Kubernetes Resource Creation               → 6:30
├─ Pod Startup & Health Checks (30-60s)       → 7:30
├─ Deployment Verification                    → 8:00
└─ Complete                                    → ~8 minutes

Note: Backend and Frontend build in parallel, reducing total time
```

---

## Deployment Pipeline Architecture

### Pipeline Topology

```
┌───────────────────────────────────────────────────────────────────┐
│                   GITHUB ACTIONS ORCHESTRATOR                      │
│                   (Runs on ubuntu-latest)                          │
└───────────┬──────────────────────────────────────────────────────┘
            │
    ┌───────┴────────────────────────────────────────┐
    │                                                 │
    ▼                                                 ▼
┌─────────────────────────┐                ┌──────────────────────────┐
│   Job 1:                │                │  Job 2:                  │
│  Change Detection       │                │  Detect Changes          │
│                         │                │  (Parallel)              │
│ • Git diff analysis     │                │ • Path-based filtering   │
│ • Component detection   │                │ • Backend/Frontend/Helm  │
└─────────────┬───────────┘                └──────────────────────────┘
              │
    ┌─────────┴──────────────┐
    │                        │
    ▼                        ▼
┌──────────────────┐   ┌──────────────────┐
│ Job 2:           │   │ Job 3:           │
│ Build Backend    │   │ Build Frontend   │
│ (Conditional)    │   │ (Conditional)    │
│                  │   │                  │
│ • Maven clean    │   │ • npm ci         │
│ • Maven package  │   │ • npm run build  │
│ • Docker build   │   │ • Docker build   │
│ • Push to ACR    │   │ • Push to ACR    │
└────────┬─────────┘   └────────┬─────────┘
         │                      │
         └──────────┬───────────┘
                    │
                    ▼
        ┌─────────────────────────────┐
        │ Job 4:                      │
        │ Deploy to Private AKS       │
        │                             │
        │ • Package Helm Chart        │
        │ • Upload to Azure Storage   │
        │ • Generate SAS URL          │
        │ • Invoke JumpVM Deployment  │
        │ • Monitor Helm Deployment   │
        └─────────────────────────────┘
                    │
                    ▼
        ┌─────────────────────────────┐
        │ Job 5:                      │
        │ Verification & Cleanup      │
        │                             │
        │ • Verify pod startup        │
        │ • Health check probes       │
        │ • Cleanup artifacts         │
        │ • Generate reports          │
        └─────────────────────────────┘
```

### Data Flow

```
Developer Code Repository
├─ ems-backend/
│  ├─ src/
│  ├─ pom.xml
│  └─ docker/backend.Dockerfile
├─ ems-fullstack/
│  ├─ src/
│  ├─ package.json
│  └─ docker/frontend.Dockerfile
└─ helm/
   └─ employee-management-system/
      ├─ Chart.yaml
      ├─ values.yaml
      └─ templates/

    ↓ (GitHub Actions)

GitHub Artifacts
├─ Backend JAR (ems-backend-1.0-SNAPSHOT.jar)
├─ Frontend Dist (dist/)
├─ Docker Images
│  ├─ myacr.azurecr.io/ems-backend:abc123
│  └─ myacr.azurecr.io/ems-frontend:abc123
└─ Helm Chart Package (employee-management-system-1.0.0.tgz)

    ↓ (ACR Registry)

Azure Container Registry
├─ ems-backend:abc123 (image layers, manifests)
├─ ems-backend:latest
├─ ems-frontend:abc123
└─ ems-frontend:latest

    ↓ (Helm Chart Storage)

Azure Storage Account (Blob)
└─ helm-charts/
   ├─ employee-management-system-1.0.0.tgz
   └─ SAS URL (generated)

    ↓ (SAS URL download link)

JumpVM
├─ Downloads Helm chart via SAS URL
├─ Authenticates with Managed Identity
├─ Retrieves AKS credentials
└─ Executes: helm upgrade --install

    ↓ (Kubernetes API - Private Endpoint)

Private AKS Cluster
├─ Control Plane (Microsoft-managed)
├─ Node Pool
│  ├─ Pod: ems-backend-xxxxx
│  │  └─ Container: ems-backend (image from ACR)
│  ├─ Pod: ems-frontend-xxxxx
│  │  └─ Container: ems-frontend (image from ACR)
│  └─ Service, Ingress, ConfigMap, Secret resources
└─ PostgreSQL Connection
   └─ Employee Database
```

---

## Stage-by-Stage Detailed Breakdown

### Stage 1: Developer Commit

#### What Happens

A developer pushes code changes to the `main` branch of the GitHub repository. The push event triggers a webhook in GitHub Actions.

#### Why This Stage Exists

- **Source of Truth:** Git is the single source of truth for all deployment artifacts
- **Version Control:** Every change is tracked with commit history
- **Traceability:** Links deployment to specific code changes
- **Audit Trail:** Who committed, when, what changed (immutable record)

#### Input

| Item | Format | Source |
|------|--------|--------|
| Code Changes | Java/JavaScript source files | Developer workstation |
| Commit Message | Text | Developer |
| Branch | main | Repository |
| Commit SHA | 40-character hex string | Git |

#### Output

| Item | Format | Destination |
|------|--------|-------------|
| Webhook Event | JSON (GitHub webhook payload) | GitHub Actions CI/CD system |
| Commit Details | Git metadata | Available to workflow |
| Code Artifact | Cloned repository | GitHub Actions runner |

#### Security Considerations

**✓ Implemented:**
- Branch protection rules (code review required before merge)
- Signed commits (recommended via GPG keys)
- Commit message enforcement (conventional commits)

**⚠ Potential Improvements:**
- Implement pre-commit hooks (lint, secret scanning)
- Use GitHub Rulesets for branch protections
- Enforce verified commits (require GPG signature)

#### Technical Details

```yaml
# GitHub Actions Trigger Configuration
on:
  push:
    branches:
      - main  # Only main branch triggers deployment
    paths:
      - 'ems-backend/**'
      - 'ems-fullstack/**'
      - 'helm/**'
      - '.github/workflows/deploy-private-aks.yml'  # Exclude docs/

  workflow_dispatch:  # Manual trigger for on-demand deployments

  workflow_run:
    workflows:
      - "Terraform Infrastructure Pipeline"
    types:
      - completed  # Trigger after infrastructure changes
```

#### Example Workflow Execution

```bash
$ git commit -m "feat: add employee filter by department"
$ git push origin main

# GitHub detects push event
# → Webhook sent to GitHub Actions
# → Workflow triggered automatically
# → Checkout step runs: git clone <repo>
# → Subsequent jobs use the cloned code
```

---

### Stage 2: GitHub Actions Trigger

#### What Happens

GitHub detects the push event and initializes the workflow orchestration system. The workflow runner (ubuntu-latest) is allocated, and environment setup begins.

#### Why This Stage Exists

- **Event Detection:** Webhook ensures deployments are triggered reliably
- **Automation:** Eliminates manual deployment steps
- **Consistency:** Same deployment process for every commit
- **Scaling:** Supports multiple concurrent deployments

#### Inputs

| Item | Source | Required |
|------|--------|----------|
| Webhook Payload | GitHub | Yes |
| Workflow Definition | .github/workflows/deploy-private-aks.yml | Yes |
| GitHub Secrets | GitHub Repository Settings | Yes |
| Runner Image | ubuntu-22.04 | Yes |

#### Outputs

| Item | Produced By | Used By |
|------|-------------|---------|
| Runner Environment | GitHub Actions | All subsequent jobs |
| GitHub Context Variables | GitHub | Workflow steps |
| Artifact Storage | Runner VM | Artifact uploads |
| Logs Sink | Runner | Job execution logs |

#### Security Considerations

**✓ Implemented:**
- Workflow validation (YAML schema enforcement)
- Secrets masked in logs (GitHub redacts ${{ secrets.* }})
- Audit logging (all workflow executions logged)

**⚠ Potential Improvements:**
- Restrict workflow permissions (limit token scopes)
- Use GitHub OIDC instead of personal access tokens
- Implement workflow approval gates for production

#### Technical Details

```yaml
# Workflow File Structure
name: Build, Push, and Deploy to Private AKS

on:
  push:
    branches: [main]
    paths:
      - 'ems-backend/**'
      - 'ems-fullstack/**'
      - 'helm/**'

env:
  AZURE_SUBSCRIPTION_ID: ${{ secrets.TF_VAR_SUBSCRIPTION_ID }}
  AZURE_TENANT_ID: ${{ secrets.TF_VAR_TENANT_ID }}
  ACR_NAME: ${{ secrets.TF_VAR_ACR_NAME }}
  ACR_LOGIN_SERVER: ${{ secrets.TF_VAR_ACR_NAME }}.azurecr.io
  AKS_CLUSTER_NAME: ${{ secrets.TF_VAR_AKS_CLUSTER_NAME }}
  RESOURCE_GROUP: ${{ secrets.TF_VAR_RESOURCE_GROUP_NAME }}

jobs:
  # Job definitions follow
```

#### Runner Lifecycle

```
1. GitHub detects push → 2. Runner allocation (takes ~5-10s)
   ↓
3. Runner initialization → 4. Workflow file parsing
   ↓
5. Job queue → 6. Parallel job execution
   ↓
7. Job completion → 8. Artifact upload
   ↓
9. Cleanup & teardown → 10. Billing stop
```

---

### Stage 3: Change Detection

#### What Happens

The workflow analyzes which files have changed and determines which components need rebuilding. Path-based filtering prevents unnecessary builds (e.g., if only documentation changed, skip Docker builds).

#### Why This Stage Exists

- **Cost Optimization:** Avoid building unchanged components
- **Time Optimization:** Parallel execution of only necessary jobs
- **Precision Deployment:** Deploy only changed components
- **Resource Efficiency:** Skip unnecessary ACR operations

#### Inputs

| Item | Source | Content |
|------|--------|---------|
| Git Diff | Repository | Changed files since last commit |
| Path Filters | Workflow config | ems-backend/**, ems-fullstack/**, helm/** |
| Previous Commit | Git history | Used for diff calculation |

#### Outputs

| Item | Format | Consumer |
|------|--------|----------|
| backend-changed | Boolean | build-backend job |
| frontend-changed | Boolean | build-frontend job |
| helm-changed | Boolean | deploy-to-aks job |

#### Security Considerations

**✓ Implemented:**
- No credentials required for change detection
- Operates on publicly visible Git history (non-sensitive)

**⚠ Potential Improvements:**
- Use GitHub's path filters (built-in security)
- Implement CODEOWNERS for approval gates
- Block deployments if security-relevant files change (without approval)

#### Technical Details

```yaml
# Change Detection Job
detect-changes:
  name: Detect Changes
  runs-on: ubuntu-latest
  outputs:
    backend-changed: ${{ steps.changes.outputs.backend }}
    frontend-changed: ${{ steps.changes.outputs.frontend }}
    helm-changed: ${{ steps.changes.outputs.helm }}

  steps:
    - name: Checkout code
      uses: actions/checkout@v4
      with:
        fetch-depth: 0  # Full history for accurate diff

    - name: Detect file changes
      id: changes
      uses: dorny/paths-filter@v2
      with:
        filters: |
          backend:
            - 'ems-backend/**'
          frontend:
            - 'ems-fullstack/**'
          helm:
            - 'helm/**'
```

#### Example Output

```
backend-changed: true   (ems-backend/src/main/java/... modified)
frontend-changed: false (ems-fullstack/ unchanged)
helm-changed: false     (helm/ unchanged)

→ Result: Only backend build job runs
→ Cost Savings: ~$0.02-0.05 per deployment (no unnecessary builds)
→ Time Savings: ~2-3 minutes (parallel execution of changed components only)
```

---

### Stage 4: Backend Build

#### What Happens

The Maven build process compiles Java source code, runs tests, and packages the application into a JAR file.

#### Why This Stage Exists

- **Compilation:** Converts source code into executable Java bytecode
- **Testing:** Validates application logic before deployment
- **Packaging:** Creates executable artifact for Docker containerization
- **Early Validation:** Catches build-time errors before container image creation

#### Inputs

| Item | Location | Format |
|------|----------|--------|
| Java Source | ems-backend/src/ | .java files |
| Dependencies | ems-backend/pom.xml | Maven coordinates |
| Test Cases | ems-backend/src/test/ | JUnit tests |
| Build Configuration | ems-backend/pom.xml | Maven configuration |

#### Outputs

| Item | Location | Size |
|------|----------|------|
| Compiled Classes | ems-backend/target/classes/ | ~50-100MB |
| JAR Artifact | ems-backend/target/*.jar | ~40-80MB |
| Test Reports | ems-backend/target/surefire-reports/ | XML files |

#### Security Considerations

**✓ Implemented:**
- Tests validate business logic
- Maven dependency scanning (optional: OWASP Dependency Check)
- JAR signed (optional: code signing)

**⚠ Potential Improvements:**
- Implement dependency scanning for CVEs (add maven-dependency-check-plugin)
- Fail build on security findings (strict mode)
- Publish SBOM (Software Bill of Materials)
- Code quality gates (SonarQube integration)

#### Technical Details

```yaml
# Backend Build Job
build-backend:
  name: Build and Push Backend
  runs-on: ubuntu-latest
  needs: detect-changes
  if: needs.detect-changes.outputs.backend-changed == 'true' || github.event_name == 'workflow_dispatch'
  
  steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Generate image tag
      id: image-tag
      run: |
        TAG=$(git rev-parse --short HEAD)  # Use commit SHA as tag
        echo "tag=${TAG}" >> $GITHUB_OUTPUT

    - name: Set up JDK 17
      uses: actions/setup-java@v3
      with:
        java-version: '17'
        distribution: 'temurin'
        cache: maven  # Cache Maven dependencies for faster builds

    - name: Build Backend JAR
      run: mvn clean package -DskipTests -q  # -q = quiet mode
      # OR with tests: mvn clean package

    - name: Publish Test Results
      if: always()
      uses: EnricoMi/publish-unit-test-result-action@v2
      with:
        files: 'ems-backend/target/surefire-reports/**/*.xml'
        check_name: 'Backend Test Results'
```

#### Maven Build Process

```
1. Clean (remove previous build artifacts)
   └─ rm -rf target/

2. Validate (check pom.xml syntax)
   └─ Maven schema validation

3. Compile (javac compilation)
   └─ src/main/java/*.java → target/classes/*.class

4. Test (JUnit test execution)
   └─ Run @Test methods
   └─ Generate surefire-reports/

5. Package (JAR creation)
   └─ jar command: create target/ems-backend-1.0-SNAPSHOT.jar
   └─ Include classes, resources, manifest

6. Verify (optional: run integration tests)
   └─ Not included in this build (-DskipTests flag)

7. Install (optional: upload to local Maven cache)
   └─ Not needed for Docker build
```

#### Performance Metrics

```
First Build (Cold Cache):
├─ Dependency Download:        45-60s
├─ Compilation:                30-45s
├─ Test Execution:             20-30s
└─ Packaging:                  5-10s
Total: ~2-3 minutes

Subsequent Builds (Warm Cache):
├─ Dependency Cache Hit:       0s
├─ Compilation (changed only): 15-20s
├─ Test Execution:             20-30s
└─ Packaging:                  5-10s
Total: ~1-2 minutes
```

---

### Stage 5: Frontend Build

#### What Happens

The Node.js build process installs dependencies, compiles React/TypeScript, and generates optimized production assets.

#### Why This Stage Exists

- **Transpilation:** Converts JSX/TypeScript to browser-compatible JavaScript
- **Bundling:** Combines modules into optimized chunks (code splitting)
- **Asset Optimization:** Minification, tree-shaking, image optimization
- **Production Build:** Generates dist/ folder for Nginx serving

#### Inputs

| Item | Location | Format |
|------|----------|--------|
| React Source | ems-fullstack/src/ | .jsx, .js files |
| TypeScript (optional) | ems-fullstack/src/ | .tsx, .ts files |
| Styles | ems-fullstack/src/ | .css files |
| Dependencies | ems-fullstack/package.json | npm packages |
| Vite Config | ems-fullstack/vite.config.js | Bundler configuration |

#### Outputs

| Item | Location | Size |
|------|----------|------|
| Production Build | ems-fullstack/dist/ | ~5-10MB (uncompressed) |
| JavaScript Bundles | dist/*.js | Tree-shaken, minified |
| CSS Files | dist/*.css | Minified, critical CSS extracted |
| HTML Entry | dist/index.html | Optimized entry point |
| Source Maps (optional) | dist/*.map | For production debugging |

#### Security Considerations

**✓ Implemented:**
- npm ci (instead of npm install) ensures locked dependencies
- package-lock.json prevents version drift
- Vite bundles with security hardening

**⚠ Potential Improvements:**
- npm audit for vulnerability scanning (fail on high/critical)
- Content Security Policy (CSP) headers in Nginx
- Subresource Integrity (SRI) for CDN-hosted assets
- SBOM generation for dependencies

#### Technical Details

```yaml
# Frontend Build Job
build-frontend:
  name: Build and Push Frontend
  runs-on: ubuntu-latest
  needs: detect-changes
  if: needs.detect-changes.outputs.frontend-changed == 'true' || github.event_name == 'workflow_dispatch'

  steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Set up Node.js
      uses: actions/setup-node@v3
      with:
        node-version: '18'  # LTS version
        cache: 'npm'
        cache-dependency-path: './ems-fullstack/package-lock.json'

    - name: Install dependencies
      run: npm ci  # Respects package-lock.json (reproducible)

    - name: Build Frontend
      run: npm run build  # Vite production build

    - name: List build artifacts
      run: ls -lah ems-fullstack/dist/
```

#### Vite Build Process

```
1. Dependency Resolution
   └─ npm ci: Install exact versions from package-lock.json

2. Source Code Processing
   ├─ JSX/React transpilation
   ├─ TypeScript compilation (if used)
   ├─ CSS/SCSS processing
   └─ Asset optimization (images, fonts)

3. Module Bundling
   ├─ Code splitting by routes
   ├─ Vendor chunk separation
   ├─ Tree-shaking (remove unused code)
   └─ Minification (terser)

4. Asset Generation
   ├─ dist/index.html (main entry)
   ├─ dist/js/*.js (application bundles)
   ├─ dist/css/*.css (stylesheets)
   ├─ dist/images/* (optimized images)
   └─ dist/favicon.ico (app icon)

5. Output
   └─ dist/ folder ready for Nginx serving
```

#### Performance Metrics

```
First Build (Cold Cache):
├─ npm ci:               20-30s (npm registry fetch)
├─ Vite build:          15-25s (bundling, minification)
└─ Total:               ~1.5-2 minutes

Subsequent Builds (Warm Cache):
├─ npm ci:              2-3s (uses node_modules cache)
├─ Vite build:          10-15s (incremental build)
└─ Total:               ~1 minute
```

---

### Stage 6: Docker Image Creation

#### What Happens

Two Docker images are built:
1. **Backend:** Maven JAR → Eclipse Temurin JRE (Alpine) → Container
2. **Frontend:** Vite dist/ → Nginx (Alpine) → Container

Both use **multi-stage builds** to minimize final image size.

#### Why This Stage Exists

- **Standardization:** Consistent runtime environment across dev/test/prod
- **Isolation:** Application dependencies don't conflict with host
- **Reproducibility:** Same image produces identical container instances
- **Security:** Non-root user, minimal base image, no unnecessary tools

#### Inputs

| Item | Source | Format |
|------|--------|--------|
| Backend JAR | ems-backend/target/*.jar | Binary JAR file |
| Frontend dist/ | ems-fullstack/dist/ | Static HTML/JS/CSS |
| Dockerfiles | docker/backend.Dockerfile, docker/frontend.Dockerfile | Multi-stage build files |
| Base Images | Docker Hub/registries | Alpine Linux variants |

#### Outputs

| Item | Registry | Tag |
|------|----------|-----|
| Backend Image | myacr.azurecr.io | ems-backend:abc123 (commit SHA) |
| Backend Image | myacr.azurecr.io | ems-backend:latest (latest build) |
| Frontend Image | myacr.azurecr.io | ems-frontend:abc123 |
| Frontend Image | myacr.azurecr.io | ems-frontend:latest |

#### Security Considerations

**✓ Implemented:**
- Non-root user execution (prevents privilege escalation)
- Minimal Alpine base images (~5MB vs 100MB+ Ubuntu)
- Multi-stage builds (removes build tools from runtime)
- Read-only root filesystem (except /tmp)
- Capability dropping (remove unnecessary Linux capabilities)

**⚠ Potential Improvements:**
- Image scanning (Trivy, Grype) before push
- Signed images (Cosign) for integrity verification
- Policy enforcement (Kyverno, OPA) for image standards
- Private base image registry (internal mirror)

#### Technical Details

**Backend Dockerfile (Multi-Stage):**
```dockerfile
# Stage 1: Build stage
FROM maven:3.9-eclipse-temurin-21-alpine AS maven-builder

WORKDIR /build
COPY pom.xml .
RUN mvn dependency:go-offline -B  # Pre-fetch dependencies for caching

COPY src src
RUN mvn clean package -DskipTests -q

# Stage 2: Runtime stage (final image)
FROM eclipse-temurin:21-jre-alpine

LABEL maintainer="Platform Engineering Team"
WORKDIR /app

# Security: Install only runtime dependencies
RUN apk add --no-cache curl && rm -rf /var/cache/apk/*

# Security: Non-root user
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# Copy JAR from build stage
COPY --from=maven-builder /build/target/*.jar app.jar

# Change ownership to non-root
RUN chown -R appuser:appgroup /app

USER appuser

EXPOSE 8080

# JVM optimizations for containers
ENV JAVA_OPTS="-XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0 -XX:InitialRAMPercentage=50.0"

ENTRYPOINT ["java", "-jar", "app.jar"]
```

**Frontend Dockerfile (Multi-Stage):**
```dockerfile
# Stage 1: Build stage
FROM node:18-alpine AS builder

WORKDIR /app
COPY package*.json ./
RUN npm ci

COPY . .
RUN npm run build  # Generates dist/ folder

# Stage 2: Runtime stage
FROM nginx:alpine

COPY nginx.conf /etc/nginx/nginx.conf
COPY --from=builder /app/dist /usr/share/nginx/html

# Security: Non-root user
RUN addgroup -S www && adduser -S www -G www
RUN chown -R www:www /usr/share/nginx/html

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=3s \
  CMD wget --quiet --tries=1 --spider http://localhost/health || exit 1
```

#### Image Size Comparison

```
Multi-Stage Backend Build:
├─ Stage 1 (Maven builder):       700MB
│  └─ Includes: Maven, JDK, compiler tools
├─ Stage 2 (Runtime):             120MB
│  └─ Includes: JRE only (no build tools)
└─ Final pushed to ACR:           120MB ✓

Single-Stage (without optimization):
└─ 700MB (includes all build tools in final image) ✗

Size Savings: ~580MB per image (~83% reduction)
```

#### Build Process Timeline

```
1. Docker builder initialization
   ├─ Load Dockerfile
   ├─ Parse stages
   └─ Initialize layer cache

2. Stage 1 execution (maven-builder)
   ├─ FROM maven:3.9... (pull base image if not cached)
   ├─ COPY pom.xml
   ├─ RUN mvn dependency:go-offline (cache layer)
   ├─ COPY src (invalidates cache if source changed)
   └─ RUN mvn clean package

3. Stage 2 execution (runtime)
   ├─ FROM eclipse-temurin:21-jre-alpine
   ├─ RUN apk add curl
   ├─ RUN adduser appuser
   ├─ COPY --from=maven-builder (copy only JAR file)
   └─ Set entrypoint

4. Image finalization
   ├─ Flatten layers (optional: experimental)
   ├─ Create image manifest
   └─ Calculate image SHA256
```

---

### Stage 7: Push Images to Azure Container Registry (ACR)

#### What Happens

Both Docker images are pushed to Azure Container Registry with two tags:
- **Commit SHA tag** (e.g., `ems-backend:abc123`) — for version tracking
- **Latest tag** (e.g., `ems-backend:latest`) — for convenient reference

#### Why This Stage Exists

- **Centralized Registry:** Single source of truth for container images
- **Network Isolation:** Private ACR endpoint (Premium SKU) prevents public exposure
- **Version Tracking:** Commit SHA enables rollback to specific commits
- **Access Control:** Azure RBAC controls who can pull/push
- **Scanning:** Optional vulnerability scanning on images

#### Inputs

| Item | Source | Format |
|------|--------|--------|
| Docker Image (Backend) | Docker daemon | OCI image format |
| Docker Image (Frontend) | Docker daemon | OCI image format |
| Azure Credentials | GitHub Secrets | Service Principal JSON |
| ACR Login Server | Environment variable | myacr.azurecr.io |

#### Outputs

| Item | Registry | Storage |
|------|----------|---------|
| Image Manifest | ACR | Image SHA256 hash |
| Layer Blobs | ACR | Individual layer storage |
| Image Tags | ACR | ems-backend:abc123, ems-backend:latest |
| Registry Metadata | ACR | Created timestamp, size |

#### Security Considerations

**✓ Implemented:**
- Azure AD authentication (service principal)
- ACR RBAC (AcrPush role for push, AcrPull for pull)
- Image immutability (optional: read-only repositories)
- Encryption at rest (Azure-managed keys)
- Network isolation (Premium SKU with private endpoints)

**⚠ Potential Improvements:**
- Image signing (Cosign) for integrity
- Image scanning (Trivy) before acceptance
- Policy enforcement (Kyverno) for deployment approval
- Geo-replication for high availability

#### Technical Details

```yaml
# ACR Push Steps
- name: Azure Login (Service Principal)
  uses: azure/login@v1
  with:
    creds: ${{ secrets.AZURE_CREDENTIALS }}
  # Outputs: Azure context available to subsequent steps

- name: Login to ACR
  run: |
    az acr login --name ${{ env.ACR_NAME }}
    # Adds credentials to Docker config (~/.docker/config.json)

- name: Build and Push backend Docker Image
  uses: docker/build-push-action@v6
  with:
    context: ./ems-backend
    file: ./docker/backend.Dockerfile
    push: true  # Push to registry after build
    tags: |
      ${{ env.ACR_LOGIN_SERVER }}/ems-backend:${{ steps.image-tag.outputs.tag }}
      ${{ env.ACR_LOGIN_SERVER }}/ems-backend:latest
    cache-from: type=gha  # Use GitHub Actions cache
    cache-to: type=gha,mode=max
```

#### ACR Image Storage

```
ACR Repository Structure:
myacr.azurecr.io/ems-backend/
├─ manifests/
│  ├─ abc123 (tag)
│  │  └─ → sha256:def456... (image SHA)
│  └─ latest (tag)
│     └─ → sha256:def456... (same SHA as abc123)
│
└─ blobs/
   ├─ sha256:aaa... (Layer 1: Alpine base)
   ├─ sha256:bbb... (Layer 2: JRE runtime)
   ├─ sha256:ccc... (Layer 3: app.jar)
   └─ sha256:ddd... (Layer 4: non-root user setup)
```

#### Authentication Flow

```
1. GitHub Actions → Service Principal credentials (from secrets)
2. az acr login → Exchange credentials for ACR token
3. Docker → Use token to authenticate push
4. ACR → Validate token, accept image layers
5. Storage → Write image blobs and manifest
6. Metadata → Record image metadata (size, created time, tags)
```

#### Image Availability

```
Before Push:
✗ Image not in ACR
✗ Cannot pull to AKS
✗ Deployment would fail (ImagePullBackOff)

After Push (Step Complete):
✓ Image available in ACR
✓ Can be pulled by AKS (via managed identity)
✓ Ready for Helm deployment

Push Duration:
├─ Image compression:   5-10s
├─ Layer upload:        10-30s (parallel for independent layers)
├─ Manifest writing:    1-2s
└─ Total:               ~20-40s
```

---

### Stage 8: Helm Package Creation & Upload to Azure Storage

#### What Happens

The Helm chart is packaged into a `.tgz` file and uploaded to Azure Blob Storage. A SAS (Shared Access Signature) URL is generated for time-limited access.

#### Why This Stage Exists

- **Deployment Configuration:** Helm chart contains all Kubernetes manifests
- **Version Management:** Chart versioning enables reproducible deployments
- **Secure Transfer:** SAS URL provides temporary, revocable access
- **Decoupled Delivery:** GitHub Actions doesn't directly deploy; uses storage as intermediary
- **Audit Trail:** Upload logged to Azure Activity Log

#### Inputs

| Item | Location | Format |
|------|----------|--------|
| Helm Chart | helm/employee-management-system/ | Chart directory |
| Chart.yaml | helm/.../Chart.yaml | Chart metadata |
| Values files | helm/.../values*.yaml | Default & environment overrides |
| Templates | helm/.../templates/ | Kubernetes manifests (templated) |

#### Outputs

| Item | Location | Format |
|------|----------|--------|
| Packaged Chart | Azure Storage | employee-management-system-1.0.0.tgz |
| SAS URL | GitHub Actions output | https://storage.../chart.tgz?sig=... |
| Upload Metadata | Activity Log | Timestamp, user, operation |

#### Security Considerations

**✓ Implemented:**
- SAS URL with time expiration (e.g., 1 hour)
- IP restrictions (optional: restrict to JumpVM IP)
- Encryption in transit (HTTPS enforced)
- Storage account HTTPS-only enforcement
- Azure RBAC on storage account

**⚠ Potential Improvements:**
- Signed SAS tokens (requires symmetric key)
- Audit logging for all blob access
- Blob versioning for rollback
- Encryption at rest with customer-managed keys

#### Technical Details

```bash
# Helm Chart Packaging
$ helm package helm/employee-management-system/
├─ Validates Chart.yaml syntax
├─ Compresses chart directory
└─ Outputs: employee-management-system-1.0.0.tgz (~50-200KB)

# Chart Contents (in .tgz)
employee-management-system-1.0.0.tgz
├─ Chart.yaml (metadata)
├─ values.yaml (default values)
├─ values-dev.yaml (dev overrides)
├─ values-prod.yaml (prod overrides)
├─ templates/
│  ├─ deployment-backend.yaml
│  ├─ deployment-frontend.yaml
│  ├─ service-backend.yaml
│  ├─ service-frontend.yaml
│  ├─ configmap.yaml
│  ├─ secret.yaml
│  ├─ hpa.yaml
│  └─ ingress.yaml
└─ Chart.lock (dependency lock)
```

```bash
# Azure Storage Upload
$ az storage blob upload \
    --account-name "stghelm${unique}" \
    --container-name "helm-charts" \
    --name "employee-management-system-1.0.0.tgz" \
    --file "./employee-management-system-1.0.0.tgz" \
    --auth-mode key

# Generate SAS URL (1 hour expiration)
$ az storage blob generate-sas \
    --account-name "stghelm${unique}" \
    --container-name "helm-charts" \
    --name "employee-management-system-1.0.0.tgz" \
    --permissions r \
    --expiry "2026-06-16T12:00:00Z" \
    --auth-mode key \
    --output tsv
```

#### SAS URL Structure

```
SAS URL Format:
https://stghelm<unique>.blob.core.windows.net/helm-charts/employee-management-system-1.0.0.tgz?sv=2021-06-08&ss=b&srt=sco&sp=rwdlac&se=2026-06-16T12:00:00Z&st=2026-06-16T11:00:00Z&spr=https&sig=xxxxxx...

Components:
├─ sv: Signed version (API version)
├─ ss: Signed services (blob)
├─ srt: Signed resource types (service/container/object)
├─ sp: Signed permissions (read, write, delete, list, add, create)
├─ se: Signed expiry (end time)
├─ st: Signed start (start time)
├─ spr: Signed protocol (https only)
└─ sig: Signature (HMAC-SHA256 of signed string)
```

#### Storage URL Lifecycle

```
1. GitHub Actions generates SAS URL
   └─ Valid for 1 hour (adjustable)

2. URL passed to JumpVM deployment script
   └─ Embedded in command parameters

3. JumpVM downloads chart using URL
   └─ Authentication via SAS token (no credentials needed)

4. SAS expiration time passes
   └─ URL becomes invalid
   └─ Any subsequent access rejected with 403 Forbidden

5. Security benefit: Limited time window for access
   └─ Even if URL leaked, access limited to 1 hour
```

---

### Stage 9: Jump VM Downloads Helm Chart

#### What Happens

GitHub Actions invokes a **remote command** on the JumpVM, which:
1. Authenticates with Managed Identity (`az login --identity`)
2. Downloads the Helm chart using the SAS URL
3. Retrieves AKS credentials
4. Executes Helm deployment

#### Why This Stage Exists

- **Private Cluster Access:** Only JumpVM can reach private AKS API server
- **Network Bridge:** JumpVM acts as intermediary between public GitHub Actions and private AKS
- **Access Control:** Managed identity restricts JumpVM permissions (least privilege)
- **Audit Trail:** All operations on JumpVM are logged

#### Inputs

| Item | Source | Format |
|------|--------|--------|
| SAS URL | GitHub Actions | HTTPS URL with token |
| JumpVM Name | Environment variable | jump-vm |
| Resource Group | Environment variable | rg-aks-3tier-dev |
| Command Script | GitHub Actions | Shell script (bash) |

#### Outputs

| Item | Destination | Format |
|------|-------------|--------|
| Helm Chart | JumpVM filesystem | /tmp/employee-management-system-1.0.0.tgz |
| kubeconfig | JumpVM ~/.kube/config | kubectl credentials |
| Helm Deployment | Private AKS | Helm release objects |

#### Security Considerations

**✓ Implemented:**
- Managed identity (no credentials stored on JumpVM)
- Azure VM Run Command (no SSH exposure)
- Temporary SAS URL (expires after use)
- Resource Group scoped permissions

**⚠ Potential Improvements:**
- Restrict commands to specific operations (no shell access)
- Enable disk encryption on JumpVM
- Use Azure Bastion for administrative access
- Implement command audit logging

#### Technical Details

```yaml
# GitHub Actions: Invoke JumpVM Deployment
- name: Deploy via Jump VM
  run: |
    az vm run-command invoke \
      --resource-group ${{ env.RESOURCE_GROUP }} \
      --name jump-vm \
      --command-id RunShellScript \
      --scripts "
        # Authenticate with Managed Identity
        az login --identity
        
        # Download Helm chart from SAS URL
        curl -L '${{ steps.sas-url.outputs.url }}' \
          -o /tmp/employee-management-system-1.0.0.tgz
        
        # Get AKS credentials
        az aks get-credentials \
          --resource-group ${{ env.RESOURCE_GROUP }} \
          --name ${{ env.AKS_CLUSTER_NAME }} \
          --admin
        
        # Extract and deploy
        helm upgrade --install ems /tmp/employee-management-system-1.0.0.tgz \
          --namespace employee-management \
          --create-namespace \
          --values ./helm/values-dev.yaml \
          --wait \
          --timeout 5m
        
        # Cleanup
        rm /tmp/employee-management-system-1.0.0.tgz
      "
```

#### Remote Execution Flow

```
1. GitHub Actions sends command to Azure REST API
   └─ Endpoint: /subscriptions/.../resourceGroups/.../providers/Microsoft.Compute/virtualMachines/jump-vm/runCommand

2. Azure Control Plane receives request
   └─ Authenticates via GitHub OIDC token
   └─ Authorizes via Azure RBAC (Contributor role on RG)

3. Command queued on JumpVM
   └─ Azure Instance Metadata Service (IMDS) delivers command

4. JumpVM executes command in Linux shell
   └─ Runs as root (security consideration)
   └─ Timeout: 90 seconds by default

5. Output captured and returned to GitHub Actions
   └─ stdout/stderr combined
   └─ Exit code returned

6. Logs stored in Azure Activity Log
   └─ WHO: GitHub Actions runner
   └─ WHAT: vm run-command invoke
   └─ WHEN: Timestamp
```

#### Managed Identity Authentication

```
Traditional Service Principal:
┌─ Store credentials (client_id, client_secret)
├─ Risk of exposure (secret in config files)
├─ Manual rotation required
└─ Difficult to audit

Managed Identity (Used Here):
┌─ Credentials managed by Azure
├─ IMDS provides tokens automatically
├─ Token refresh handled transparently
├─ No credentials in storage
└─ Audit via Azure AD events

az login --identity Flow:
1. Application calls Azure SDK
2. SDK queries IMDS endpoint (169.254.169.254)
3. IMDS returns access token (valid 1 hour)
4. Token used to authenticate API calls
5. Token refresh automatic (before expiration)
6. No credential storage needed
```

---

### Stage 10: Managed Identity Authentication

#### What Happens

The JumpVM uses its **system-assigned managed identity** to authenticate with Azure services without storing credentials.

#### Why Managed Identity Instead of Service Principals

| Aspect | Service Principal | Managed Identity (Selected) |
|--------|-------------------|----------------------------|
| **Credentials** | Client secret (stored, rotated manually) | Token from IMDS (automatic) |
| **Storage** | Config files, env vars, vaults | None (IMDS-provided) |
| **Rotation** | Manual process (risky) | Automatic (Azure-managed) |
| **Exposure Risk** | High (secrets in files) | Minimal (no secrets) |
| **Audit Trail** | Limited | Full Azure AD audit |
| **Cost** | None (no licensing) | None (included with VM) |
| **Complexity** | Moderate (credential mgmt) | Low (transparent) |

#### Inputs

| Item | Source | Format |
|------|--------|--------|
| JumpVM Managed Identity | Azure Resource (System-assigned) | Object ID, Client ID |
| IMDS Endpoint | Azure Fabric | HTTP metadata service |
| RBAC Role Assignments | Azure RBAC | Assigned roles |

#### Outputs

| Item | Produced | Validity |
|------|----------|----------|
| Access Token | Azure STS | 1 hour |
| Refresh Token | Azure STS | Valid until revoked |
| Token Claims | JWT token | User identity, roles |

#### Security Considerations

**✓ Implemented:**
- Tokens never stored (IMDS provides on-demand)
- Automatic rotation (before expiration)
- IMDS access restricted to VM local network
- Tokens include expiration and scope

**⚠ Potential Improvements:**
- Implement token cache with rotation logic
- Monitor token refresh failures
- Use Managed Identity for all Azure SDK calls
- Implement circuit breaker pattern

#### Technical Details

```bash
# JumpVM: Login with Managed Identity
$ az login --identity
[
  {
    "cloudName": "AzureCloud",
    "homeTenantId": "12345678-...",
    "id": "00000000-0000-0000-0000-000000000000",
    "isDefault": true,
    "managedByTenants": [],
    "name": "Azure subscription 1",
    "state": "Enabled",
    "tenantId": "12345678-...",
    "user": {
      "name": "systemAssignedIdentity@azure.local",
      "type": "servicePrincipal"
    }
  }
]

# No password or secret provided!
# Authentication is implicit from Managed Identity
```

#### Token Exchange Mechanism

```
JumpVM wants to call Azure API:

1. JumpVM application calls: az aks get-credentials ...
2. Azure CLI detects context (no explicit credentials)
3. Azure CLI queries IMDS: GET http://169.254.169.254/metadata/identity/oauth2/token?...
4. IMDS validates request source (internal VM network)
5. IMDS consults Azure Control Plane:
   └─ "What identity is this VM using?"
   └─ "Does this identity have permission for this operation?"
6. If authorized:
   └─ IMDS returns access token
   └─ Token is JWT containing identity claims
7. Azure CLI uses token to authenticate API request:
   └─ Authorization: Bearer <token>
8. Azure Resource Manager validates token:
   └─ Token signature (verify authenticity)
   └─ Token claims (identity, roles)
   └─ Token expiration (not expired)
9. If valid:
   └─ Request authorized based on RBAC role assignments
   └─ Response returned to JumpVM
10. Token lifecycle:
    └─ Issued: Current time
    └─ Expires: +1 hour
    └─ Cached: By Azure SDK (automatic refresh before expiration)
```

#### RBAC Role Assignments for Managed Identity

```
JumpVM Managed Identity receives roles:

Role: Contributor (on AKS Resource Group)
├─ Allows: Full management of resources
├─ Includes: AKS cluster access, get-credentials
└─ Scope: rg-aks-3tier-dev

Role: AcrPull (on ACR)
├─ Allows: Pull images from registry
├─ Used by: kubelet for image pulls
└─ Scope: myacr.azurecr.io

Role: Reader (on Azure Subscription)
├─ Allows: Read-only access to resources
├─ Used for: Querying resource status
└─ Scope: /subscriptions/...

RBAC Check Flow:
1. Request: JumpVM calls "az aks get-credentials"
2. Identity: Managed Identity extracts from IMDS
3. Operation: Maps to "Microsoft.ContainerService/managedClusters/listClusterAdminCredential/action"
4. Scope: Resource Group (rg-aks-3tier-dev)
5. Role: Contributor role includes this action
6. Result: ✓ Authorization succeeds
7. Response: kubeconfig returned
```

---

### Stage 11: AKS Credential Retrieval

#### What Happens

JumpVM executes `az aks get-credentials` to retrieve the kubeconfig file, enabling kubectl access to the private AKS cluster.

#### Why This Stage Exists

- **Authentication Setup:** kubeconfig provides credentials for kubectl
- **Authorization:** kubeconfig contains cluster endpoint, certificate authority, tokens
- **Context Switching:** Enables access to specific AKS cluster
- **Admin Context:** Retrieved with `--admin` flag for cluster operations

#### Inputs

| Item | Source | Format |
|------|--------|--------|
| Subscription ID | Environment variable | GUID |
| Resource Group | Environment variable | rg-aks-3tier-dev |
| Cluster Name | Environment variable | aks-ems-dev |
| Admin Flag | Command parameter | --admin |

#### Outputs

| Item | Location | Format |
|------|----------|--------|
| kubeconfig | ~/.kube/config | YAML file |
| Cluster Endpoint | kubeconfig | Private API server endpoint (no public IP) |
| CA Certificate | kubeconfig | Base64-encoded PEM |
| Client Certificate | kubeconfig (optional) | Authentication credential |

#### Security Considerations

**✓ Implemented:**
- kubeconfig file is sensitive (contains authentication data)
- File permissions 600 (readable only by owner)
- Short-lived tokens (optional: configurable expiration)
- Audit logging (who retrieved credentials, when)

**⚠ Potential Improvements:**
- Use Azure AD for kubectl authentication (instead of certificates)
- Implement kubectl audit logging
- Use token-based authentication with expiration
- Restrict credentials to specific namespaces

#### Technical Details

```bash
# Retrieve AKS Admin Credentials
$ az aks get-credentials \
    --resource-group rg-aks-3tier-dev \
    --name aks-ems-dev \
    --admin \
    --file ~/.kube/config \
    --overwrite

# Output structure
$ cat ~/.kube/config
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: LS0tLS1CRUdJ...  # Base64-encoded CA cert
    server: https://aks-ems-dev.privatednsa...  # Private endpoint (not public)
  name: aks-ems-dev
contexts:
- context:
    cluster: aks-ems-dev
    user: clusterAdmin_rg-aks-3tier-dev_aks-ems-dev
  name: aks-ems-dev
current-context: aks-ems-dev
kind: Config
preferences: {}
users:
- name: clusterAdmin_rg-aks-3tier-dev_aks-ems-dev
  user:
    client-certificate-data: LS0tLS1CRUdJ...  # Client certificate
    client-key-data: LS0tLS1QUklWQVRF...      # Client key
```

#### Kubeconfig Components

```
kubeconfig contains three main sections:

1. Clusters
   └─ Defines Kubernetes cluster endpoints
   └─ Contains:
      ├─ server: API server endpoint (private: https://aks-...privatednsa...)
      ├─ certificate-authority-data: PEM cert for verifying server
      └─ name: Cluster identifier

2. Contexts
   └─ Links cluster + user + namespace
   └─ Contains:
      ├─ cluster: Reference to cluster definition
      ├─ user: Reference to user credentials
      └─ namespace: Default namespace for commands

3. Users
   └─ Defines authentication credentials
   └─ Contains (for admin context):
      ├─ client-certificate-data: Admin certificate
      └─ client-key-data: Private key

4. Current Context
   └─ Which cluster/user/namespace is active
   └─ Used by default if no context specified
```

#### Private Endpoint Access

```
Public AKS (Not Used):
$ kubectl get nodes
→ Connects to: https://aks-ems-dev.westus2.azmk8s.io:443 (PUBLIC IP)
→ Accessible from: Anywhere on Internet
→ Risk: Public exposure of Kubernetes API

Private AKS (Used Here):
$ kubectl get nodes
→ Connects to: https://aks-ems-dev.privatednsa...:443 (PRIVATE IP)
→ Accessible from: JumpVM only (via VNet)
→ Risk: Minimized (only internal access)

Private endpoint resolution:
1. kubectl reads kubeconfig (server address)
2. Resolves: aks-ems-dev.privatednsa... → 10.0.1.5 (private IP)
3. Connects to: 10.0.1.5:443 (within VNet)
4. mTLS negotiation (certificate validation)
5. Authenticated request sent
```

---

### Stage 12: Helm Upgrade/Install

#### What Happens

Helm executes `helm upgrade --install` which:
1. **Reads** the packaged Helm chart
2. **Renders** templates using provided values (substituting variables)
3. **Compares** rendered manifests with current cluster state
4. **Applies** Kubernetes resources (create/update/delete as needed)
5. **Waits** for deployment to reach ready state

#### Why This Stage Exists

- **Declarative Deployment:** Helm chart is source of truth for cluster state
- **Idempotent:** Running same command twice produces same result
- **Version Management:** Each Helm release is versioned for rollback
- **Environment Overrides:** Different values.yaml for dev/staging/prod
- **Dependency Management:** Charts can depend on sub-charts (e.g., PostgreSQL)

#### Why Helm Was Chosen Instead of kubectl apply

| Aspect | kubectl apply | Helm (Selected) |
|--------|---------------|-----------------|
| **Templating** | None (static YAML) | Full templating (loops, conditions) |
| **Values Management** | Manual env var substitution | Built-in values.yaml override system |
| **Release Versioning** | No versioning | Release history with rollback |
| **Upgrade Logic** | Three-way merge (complex) | Intelligent upgrade detection |
| **Dependency Management** | Manual orchestration | Sub-chart dependency handling |
| **Idempotence** | Operator-dependent | Guaranteed idempotent |
| **Debugging** | Difficult (debug manifests) | helm template for inspection |
| **Community Ecosystem** | Limited (custom solutions) | Artifact Hub (100K+ charts) |

#### Inputs

| Item | Source | Format |
|------|--------|--------|
| Helm Chart | Azure Storage | Packaged .tgz file |
| values-dev.yaml | Repository | YAML configuration |
| Image Tags | GitHub Actions job output | ems-backend:abc123 |
| Namespace | Helm command | employee-management |

#### Outputs

| Item | Destination | Type |
|------|-------------|------|
| Helm Release | AKS cluster | Named release (ems) |
| Kubernetes Resources | AKS etcd | Deployments, Services, ConfigMaps, Secrets |
| Release History | Helm Storage | Previous releases (rollback capability) |

#### Security Considerations

**✓ Implemented:**
- Secrets stored in Kubernetes Secret objects (encrypted at rest in etcd)
- ConfigMaps for non-sensitive configuration
- RBAC for pod service accounts
- Network policies for pod-to-pod communication

**⚠ Potential Improvements:**
- Use Azure Key Vault Provider for secret storage (instead of Kubernetes Secrets)
- Implement Kyverno policies for security validation
- Use sealed-secrets or external-secrets for production
- Implement Pod Disruption Budgets (PDB) for availability

#### Technical Details

```bash
# Helm Upgrade/Install Command
$ helm upgrade --install ems ./helm/employee-management-system \
    --namespace employee-management \
    --create-namespace \
    --values helm/values-dev.yaml \
    --set backend.image.tag=abc123 \
    --set frontend.image.tag=abc123 \
    --wait \
    --timeout 5m

# Command breakdown:
├─ upgrade: Update existing release (or create if not exists)
├─ --install: Create release if it doesn't exist
├─ ems: Release name
├─ ./helm/.../: Chart path
├─ --namespace: Kubernetes namespace
├─ --create-namespace: Create namespace if doesn't exist
├─ --values: Apply values-dev.yaml overrides
├─ --set: Override specific values (image tags)
├─ --wait: Wait for Deployment readiness
└─ --timeout: Max wait time before failure
```

#### Helm Chart Rendering Process

```
1. Load Chart
   └─ Read Chart.yaml, values.yaml, templates/

2. Merge Values
   ├─ Start with: helm/values.yaml (defaults)
   ├─ Override with: helm/values-dev.yaml
   ├─ Override with: --set backend.image.tag=abc123
   └─ Result: Effective values object

3. Render Templates
   ├─ For each template (deployment.yaml, service.yaml, etc.)
   ├─ Substitute: {{ .Values.backend.image.tag }} → abc123
   ├─ Execute: Helm template functions (loops, conditionals)
   └─ Output: Raw Kubernetes manifests

4. Validate Manifests
   └─ kubectl --dry-run=client (schema validation)

5. Compute Diff
   ├─ Fetch current resources from cluster
   ├─ Compare: Current vs. Desired (rendered templates)
   └─ Determine: Create/Update/Delete/No-op operations

6. Apply Changes
   ├─ Create: New resources
   ├─ Update: Modified resources (three-way merge)
   ├─ Delete: Removed resources (if policy allows)
   └─ Order: Respect resource dependencies

7. Monitor Rollout
   ├─ Wait for: Deployment replica readiness
   ├─ Check: liveness/readiness probes
   └─ Timeout: After 5 minutes, fail if not ready
```

#### Example Values-Dev.yaml

```yaml
# helm/values-dev.yaml
backend:
  replicaCount: 2
  image:
    repository: myacr.azurecr.io/ems-backend
    tag: "latest"  # Overridden by --set during deployment
    pullPolicy: Always  # Always pull (pick up latest)
  
  springProfile: dev
  
  resources:
    requests:
      cpu: 250m       # Minimum for scheduling
      memory: 512Mi
    limits:
      cpu: 500m       # Maximum allowed
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

database:
  host: pgemsdev.postgres.database.azure.com
  port: 5432
  name: employee_db
  ssl: true
  maxConnections: 20
```

#### Helm Release Management

```
Release Lifecycle:

1. First Deployment
   $ helm install ems ./chart
   └─ Creates: Release named "ems"
   └─ Version: 1
   └─ Status: deployed

2. Code Update
   $ helm upgrade ems ./chart --set image.tag=xyz789
   └─ Updates: Release "ems" to new version
   └─ Version: 2
   └─ Status: deployed
   └─ Previous version preserved (revision 1)

3. Check Release History
   $ helm history ems
   REVISION UPDATED             STATUS      CHART
   1        Mon Jun 16 10:00:00 deployed    ems-1.0.0
   2        Mon Jun 16 10:15:00 deployed    ems-1.0.0

4. Rollback if Needed
   $ helm rollback ems 1
   └─ Reverts to: Version 1
   └─ New Version: 3 (with old manifests)
   └─ Status: deployed
```

---

### Stage 13: Kubernetes Resource Updates

#### What Happens

Kubernetes control plane receives the manifests from Helm and updates the cluster state:

1. **etcd Update:** Resources stored in distributed key-value store
2. **Controller Reconciliation:** Controllers detect changes and create pods
3. **Pod Scheduling:** Scheduler assigns pods to nodes
4. **Container Startup:** Kubelet pulls images and starts containers
5. **Network Setup:** CNI plugin configures pod networking

#### Why This Stage Exists

- **Persistent State:** Resources stored in etcd for cluster state management
- **Declarative Infrastructure:** Kubernetes maintains desired state
- **Distributed Orchestration:** Controllers handle complex scheduling/networking
- **Self-Healing:** Failed pods automatically restarted

#### Inputs

| Item | Source | Type |
|------|--------|------|
| Manifest | Helm | Kubernetes resources (YAML) |
| Desired State | Helm values | Configuration |
| Image References | GitHub Actions | Docker image URIs from ACR |

#### Outputs

| Item | State | Status |
|------|-------|--------|
| Deployment | Created/Updated | Ready |
| Pods | Running | Healthy |
| Services | Created | IP allocated |
| ConfigMaps | Created | Values stored |
| Secrets | Created | Encrypted at rest |

#### Kubernetes Resource Architecture

```
# Manifest Example (generated by Helm)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ems-backend
  namespace: employee-management
spec:
  replicas: 2  # Desired state
  selector:
    matchLabels:
      app: ems-backend
  template:
    metadata:
      labels:
        app: ems-backend
    spec:
      containers:
      - name: backend
        image: myacr.azurecr.io/ems-backend:abc123  # From GitHub Actions output
        ports:
        - containerPort: 8080
        resources:
          requests:
            cpu: 250m          # Minimum for scheduler
            memory: 512Mi
          limits:
            cpu: 500m          # Maximum allowed
            memory: 1Gi
        env:
        - name: DATABASE_URL
          valueFrom:
            configMapKeyRef:
              name: ems-config
              key: db-url
        - name: DATABASE_PASSWORD
          valueFrom:
            secretKeyRef:
              name: ems-secrets
              key: db-password
        livenessProbe:         # Is app responsive?
          httpGet:
            path: /actuator/health/liveness
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:        # Can app handle traffic?
          httpGet:
            path: /actuator/health/readiness
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 5
```

#### Deployment Reconciliation Flow

```
1. Helm applies manifest to Kubernetes API
   └─ POST /apis/apps/v1/namespaces/employee-management/deployments

2. API Server validates manifest
   ├─ Schema validation (required fields present)
   ├─ Webhook validation (custom validation policies)
   └─ Authorization check (RBAC)

3. Manifest stored in etcd
   └─ Kubernetes persistent state

4. Deployment Controller detects change
   └─ Watches: /apis/apps/v1/deployments
   └─ Sees: New Deployment or updated spec

5. Controller reconciliation loop
   ├─ Current state: 0 pods (assuming first deployment)
   ├─ Desired state: 2 pods
   ├─ Difference: 2 pods needed
   └─ Action: Create 2 ReplicaSets

6. ReplicaSet Controller detects ReplicaSet creation
   ├─ Current state: 0 pods
   ├─ Desired state: 2 pods
   ├─ Action: Create Pod objects (2 specs)
   └─ Store in etcd

7. Scheduler detects pending Pods
   ├─ Find: Pods with no node assignment
   ├─ Evaluate: Available nodes, resource requests
   ├─ Select: Node meeting CPU/memory requirements
   └─ Bind: Pod → Node (store in etcd)

8. Kubelet (on assigned node) detects pod assignment
   ├─ Watch: Pod resources on node
   ├─ See: New pod assignment
   ├─ Pull: Docker image from ACR (via managed identity)
   ├─ Create: Container (CRI call)
   └─ Manage: Container lifecycle

9. Pod startup sequence
   ├─ Init containers (if any)
   ├─ Main container start
   ├─ Wait: liveness probe starts passing
   └─ Mark: Pod Running

10. Container health checks
    ├─ readinessProbe: POST /actuator/health/readiness
    │  └─ If passes: Pod added to service endpoints
    └─ livenessProbe: POST /actuator/health/liveness
       └─ If fails: Container restarted
```

#### Managed Identity in Pod Pull

```
Before: Service Principal Model (Anti-pattern)
├─ Config file contains: client_id, client_secret
├─ Risk: Secret exposed in config
├─ Scaling: Secret shared across many pods
└─ Rotation: Manual process

Now: Managed Identity Model (Implemented)
├─ Kubelet uses: Pod identity
├─ Image pull request: "Pull image from ACR"
├─ IMDS endpoint: "What identity should pull?"
├─ IMDS response: "Use kubelet managed identity"
├─ Token obtained: Via IMDS (no secret storage)
├─ ACR authentication: Using token
└─ Image pull: Succeeds

Security Advantage:
✓ No secrets in config
✓ Automatic token rotation
✓ Audit trail of pulls
✓ Fine-grained RBAC per identity
```

---

### Stage 14: Deployment Verification

#### What Happens

GitHub Actions monitors deployment progress and validates that pods are healthy:

1. **Pod Readiness Check:** Wait for all pods to reach Ready state
2. **Health Probe Validation:** Liveness/readiness probes passing
3. **Replicas Check:** Actual replicas match desired count
4. **Service Availability:** Load balancer endpoint responding
5. **Application Health:** HTTP endpoint returning 200 OK

#### Why This Stage Exists

- **Fail Fast:** Catch deployment issues immediately
- **Confidence:** Verify application is actually running
- **Automation:** No manual verification needed
- **Audit Trail:** Deployment verification logged

#### Inputs

| Item | Source | Format |
|------|--------|--------|
| Helm Release | JumpVM Helm | Release objects in cluster |
| Deployment Status | Kubernetes API | Pod readiness state |
| Service Endpoint | Kubernetes API | LoadBalancer/ClusterIP |

#### Outputs

| Item | Destination | Format |
|------|-------------|--------|
| Verification Result | GitHub Actions log | Pass/Fail status |
| Metrics | GitHub Actions step output | Pod counts, health |
| Deployment Report | GitHub Actions summary | Success/failure details |

#### Security Considerations

**✓ Implemented:**
- Health checks validate application functionality
- Liveness probes prevent stuck containers
- Readiness probes ensure traffic only to healthy pods

**⚠ Potential Improvements:**
- Smoke tests (verify API endpoints)
- Security scanning of running containers
- Compliance checks (verify resource limits, RBAC)
- Performance baselines

#### Verification Steps

```bash
# 1. Wait for deployment readiness
$ kubectl rollout status deployment/ems-backend \
    --namespace employee-management \
    --timeout=5m

# Output: "deployment "ems-backend" successfully rolled out"

# 2. Check pod status
$ kubectl get pods -n employee-management
NAME                            READY   STATUS    RESTARTS   AGE
ems-backend-5c7f6d4b8-abc12     1/1     Running   0          2m
ems-backend-5c7f6d4b8-xyz78     1/1     Running   0          1m
ems-frontend-7a8b9c2d5-def45    1/1     Running   0          2m
ems-frontend-7a8b9c2d5-ghi67    1/1     Running   0          1m

# 3. Check pod health probes
$ kubectl describe pod ems-backend-5c7f6d4b8-abc12 -n employee-management
...
Liveness probe: http-get on port 8080 path=/actuator/health/liveness
  Successful probes: 12
  Failed probes: 0
Readiness probe: http-get on port 8080 path=/actuator/health/readiness
  Successful probes: 12
  Failed probes: 0

# 4. Check service endpoint
$ kubectl get svc ems-backend-service -n employee-management
NAME                   TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)
ems-backend-service    ClusterIP   10.0.100.12     <none>        8080/TCP

# 5. Test application endpoint
$ curl http://ems-backend-service:8080/actuator/health
{"status":"UP"}
```

#### Deployment Verification Script

```bash
#!/bin/bash
# Verification script (can be run from GitHub Actions or manually)

set -e

NAMESPACE="employee-management"
TIMEOUT="5m"
BACKEND_DEPLOYMENT="ems-backend"
FRONTEND_DEPLOYMENT="ems-frontend"

echo "=== Deployment Verification ==="

# 1. Check Deployments
echo "Checking backend deployment..."
kubectl rollout status deployment/$BACKEND_DEPLOYMENT \
  -n $NAMESPACE \
  --timeout=$TIMEOUT

echo "Checking frontend deployment..."
kubectl rollout status deployment/$FRONTEND_DEPLOYMENT \
  -n $NAMESPACE \
  --timeout=$TIMEOUT

# 2. Check Pod Count
echo "Verifying pod counts..."
BACKEND_PODS=$(kubectl get pods -n $NAMESPACE -l app=ems-backend --no-headers | wc -l)
echo "Backend pods running: $BACKEND_PODS"

# 3. Check Health Probes
echo "Verifying health probes..."
for pod in $(kubectl get pods -n $NAMESPACE -l app=ems-backend -o jsonpath='{.items[*].metadata.name}'); do
  echo "Checking pod: $pod"
  kubectl describe pod $pod -n $NAMESPACE | grep -A 2 "Probe"
done

# 4. Test Service Endpoint
echo "Testing service endpoint..."
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl -f http://ems-backend-service:8080/actuator/health

echo "=== Verification Complete ==="
```

#### Health Check Probes

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: ems-backend
spec:
  containers:
  - name: backend
    image: myacr.azurecr.io/ems-backend:abc123
    
    # Liveness Probe: Is the app running?
    livenessProbe:
      httpGet:
        path: /actuator/health/liveness
        port: 8080
        scheme: HTTP
      initialDelaySeconds: 30  # Wait 30s before first probe
      periodSeconds: 10        # Check every 10s
      timeoutSeconds: 3        # Give 3s for response
      failureThreshold: 3      # Restart after 3 failures
      successThreshold: 1      # 1 success = healthy
    
    # Readiness Probe: Can the app handle traffic?
    readinessProbe:
      httpGet:
        path: /actuator/health/readiness
        port: 8080
        scheme: HTTP
      initialDelaySeconds: 10  # Wait 10s before first probe
      periodSeconds: 5         # Check every 5s
      timeoutSeconds: 3
      failureThreshold: 3
      successThreshold: 1
```

#### Probe Failure Handling

```
Scenario 1: Liveness Probe Fails
├─ 3 consecutive failures
├─ kubelet action: Kill container
├─ ReplicaSet action: Start new container
├─ Result: Automatic container restart (self-healing)

Scenario 2: Readiness Probe Fails
├─ 3 consecutive failures
├─ kubelet action: Mark pod NotReady
├─ Service endpoint: Pod removed from load balancer
├─ Traffic: Redirected to healthy pods
├─ Result: Unhealthy pod isolated (no impact on users)

Scenario 3: Pod Crashes
├─ Container process exits
├─ kubelet action: Detect exit
├─ ReplicaSet action: Start new container
├─ Restart count: Incremented
├─ Result: Automatic recovery
```

---

### Stage 15: Cleanup Activities

#### What Happens

After successful deployment, the workflow performs cleanup to remove temporary artifacts and prevent storage bloat:

1. **Temporary File Removal:** Delete downloaded Helm charts from GitHub Actions runner
2. **Cache Management:** Update GitHub Actions cache for subsequent runs
3. **Storage Cleanup:** Optional: Delete old versions from Azure Storage
4. **Artifact Cleanup:** Remove build artifacts from GitHub Actions

#### Why This Stage Exists

- **Disk Space:** Prevent GitHub Actions runner from filling up
- **Cost Optimization:** Minimize storage costs
- **Security:** Remove sensitive files (credentials) from runners
- **Hygiene:** Keep workspace clean for next deployment

#### Inputs

| Item | Source | Location |
|------|--------|----------|
| Temporary Files | Previous steps | /tmp/, ./ems-backend/target/ |
| Cache Data | Maven/npm | ~/.m2/, node_modules/ |
| Old Charts | Azure Storage | Previous versions |

#### Outputs

| Item | State | Result |
|------|-------|--------|
| Disk Space | Freed | ~500MB-1GB available |
| Storage Costs | Reduced | Fewer old versions stored |
| Audit Log | Updated | Cleanup operations logged |

#### Security Considerations

**✓ Implemented:**
- Temporary files deleted (no credential leakage)
- GitHub Actions artifacts encrypted at rest
- Cache contains no secrets (unless explicitly added)

**⚠ Potential Improvements:**
- Implement file shredding (secure deletion, not just rm)
- Encrypt GitHub Actions cache
- Audit log file deletion events
- Implement retention policies

#### Technical Details

```yaml
# GitHub Actions Cleanup Steps
- name: Cleanup temporary files
  if: always()  # Run even if previous steps failed
  run: |
    # Remove Maven build artifacts
    rm -rf ./ems-backend/target/
    
    # Remove npm modules (GitHub Actions cache used instead)
    rm -rf ./ems-fullstack/node_modules/
    
    # Remove downloaded Helm chart from JumpVM /tmp
    # (JumpVM deployment script handles this)
    
    # Clear Docker build cache (optional, frees space)
    docker system prune -a -f --volumes

- name: Upload coverage reports (optional)
  uses: codecov/codecov-action@v3
  with:
    files: ./ems-backend/target/surefire-reports/**

- name: Archive deployment logs
  if: always()
  uses: actions/upload-artifact@v3
  with:
    name: deployment-logs-${{ github.run_id }}
    path: logs/
    retention-days: 30  # Keep for 30 days then auto-delete
```

#### Cleanup Flow

```
Before Cleanup:
├─ GitHub Actions Runner Disk: 95% full (~45GB used)
├─ Docker layers cache: ~10GB
├─ Maven cache (~/.m2/): ~5GB
├─ npm node_modules: ~2GB
└─ Temporary files (/tmp/): ~500MB

Cleanup Operations:
├─ rm -rf target/ (build artifacts)
├─ rm -rf node_modules/
├─ docker system prune (unused layers)
└─ Clear /tmp/

After Cleanup:
├─ GitHub Actions Runner Disk: 45% full (~20GB used)
├─ Docker layers cache: ~2GB (pruned)
├─ Maven cache: Retained (next build faster)
├─ npm node_modules: Removed (GitHub cache used)
└─ Temporary files: Deleted
```

#### Azure Storage Cleanup (Helm Charts)

```bash
# Optional: Delete old Helm chart versions from Azure Storage
$ az storage blob list \
    --account-name stghelm \
    --container-name helm-charts \
    --query "[?contains(name, 'employee-management')].name" \
    -o tsv | tail -n +6  # Keep last 5 versions

# Delete old versions
$ az storage blob delete \
    --account-name stghelm \
    --container-name helm-charts \
    --name employee-management-system-0.0.1.tgz

# Result: Storage costs reduced, only recent versions retained
```

---

## Security Architecture

### End-to-End Security Model

The deployment pipeline implements multiple layers of security:

```
Layer 1: Source Control
├─ Branch protection (code review required)
├─ Commit signing (optional, recommended)
└─ CODEOWNERS enforcement

Layer 2: CI/CD Pipeline
├─ GitHub Actions (OIDC-based authentication)
├─ Secrets management (masked in logs)
├─ Artifact scanning (optional)
└─ Signed container images (optional)

Layer 3: Artifact Storage
├─ ACR (network isolation, RBAC)
├─ Azure Storage (encryption, access policies)
└─ Managed identity authentication

Layer 4: Network Transport
├─ HTTPS everywhere (TLS 1.2+)
├─ Private VNet (no internet exposure)
├─ Network Security Groups (firewalls)
└─ Azure Bastion (SSH/RDP over internet)

Layer 5: Authentication/Authorization
├─ Azure AD/Entra ID
├─ Managed identities (no credential storage)
├─ RBAC (fine-grained access control)
└─ Pod security policies

Layer 6: Encryption
├─ At-rest: etcd encryption, database encryption
├─ In-transit: TLS for all connections
└─ Container images: Signed (optional)
```

### Key Security Decisions

| Decision | Why | Benefit |
|----------|-----|---------|
| **Private AKS** | No public API server | Eliminates public attack surface |
| **Managed Identity** | No credential storage | Automatic rotation, no key leakage |
| **JumpVM Bastion** | Single access point | Centralized access control, audit |
| **SAS URL** | Time-limited token | Revocable access, expiration |
| **Multi-stage Dockerfile** | Minimal runtime image | Reduced CVE attack surface |
| **Non-root User** | Least privilege | Container breakout impact limited |
| **Network Policies** | Pod-to-pod rules | Microsegmentation |
| **RBAC** | Fine-grained permissions | Prevent unauthorized actions |

---

## Error Handling & Recovery

### Error Detection Mechanisms

```
Stage 1: GitHub Actions Workflow
├─ Job failure detection: Exit code != 0
├─ Step timeout: 6-hour default
├─ Resource limit: 6-hour max per job
└─ Action: Workflow marked as FAILED

Stage 2: Build Failures
├─ Maven compile error: Caught, logged
├─ npm build error: Caught, logged
├─ Docker build failure: Image not created
└─ Action: Stop pipeline, alert developers

Stage 3: ACR Push Failure
├─ Network timeout: Retry mechanism
├─ Authentication failure: Check credentials
├─ Insufficient quota: Monitor usage
└─ Action: Fail deployment, preserve previous release

Stage 4: Helm Deployment Failure
├─ Manifest validation failure: Caught by API server
├─ Pod crash during startup: Detected by kubelet
├─ Image pull failure: ImagePullBackOff status
├─ Resource limit exceeded: Pod OOMKilled
└─ Action: Helm rollback triggered

Stage 5: Health Check Failure
├─ Liveness probe fails: Container restarted
├─ Readiness probe fails: Pod marked NotReady
├─ Deployment timeout: Deployment fails
└─ Action: Investigate root cause, fix, retry
```

### Recovery Strategies

```
Recovery Strategy 1: Automatic Retry
├─ Suitable for: Transient failures (network, timeouts)
├─ Implementation: GitHub Actions retry mechanism
├─ Example: $ action-retry --max-attempts 3
└─ Outcome: Often succeeds on subsequent attempts

Recovery Strategy 2: Manual Retry
├─ Suitable for: Credential issues, quota limits
├─ Implementation: Re-run workflow in GitHub UI
├─ Example: "Re-run failed jobs" button
└─ Outcome: Developer fixes issue, reruns

Recovery Strategy 3: Helm Rollback
├─ Suitable for: Deployment breaks application
├─ Implementation: $ helm rollback ems 1
├─ Example: Revert to previous working version
└─ Outcome: Application reverts to previous state

Recovery Strategy 4: Manual Investigation
├─ Suitable for: Complex failures
├─ Implementation: SSH to JumpVM, kubectl debugging
├─ Example: $ kubectl logs -f pod-name
└─ Outcome: Root cause identified, fix applied
```

### Specific Failure Scenarios & Recovery

**Scenario 1: Maven Build Failure**
```
Failure: [ERROR] Failed to execute goal org.apache.maven.plugins:maven-compiler-plugin...

Detection:
├─ mvn command exits with code != 0
└─ GitHub Actions detects failure

Recovery:
├─ Developer reviews build output
├─ Fix compilation error in source code
├─ Commit fix
├─ Workflow automatically re-triggered
└─ Pipeline retries from beginning
```

**Scenario 2: ACR Login Failure**
```
Failure: [ERROR] Failed to authenticate with ACR

Detection:
├─ az acr login fails
└─ Docker push step skipped

Potential Causes:
├─ Service principal credentials expired
├─ ACR access policy changed
└─ Network connectivity issue

Recovery:
├─ Verify GitHub Secrets are current
├─ Check Azure credentials (not expired)
├─ Verify service principal has AcrPush role
├─ Retry pipeline
└─ If persists: Contact Azure admins
```

**Scenario 3: Helm Deployment Timeout**
```
Failure: Helm deployment timeout after 5 minutes

Detection:
├─ Pods remain NotReady after timeout
└─ Deployment fails

Potential Causes:
├─ Image pull timeout (network issue)
├─ Pod crash loop (application error)
├─ Insufficient cluster resources
└─ Liveness probe timeout

Recovery:
├─ SSH to JumpVM
├─ Check pod status: kubectl describe pod <pod-name>
├─ Review pod logs: kubectl logs <pod-name>
├─ If app issue: Fix code, redeploy
├─ If resource issue: Scale cluster, retry
└─ If image issue: Verify ACR access, retry
```

**Scenario 4: Image Pull Failure (ImagePullBackOff)**
```
Failure: Pod stuck in ImagePullBackOff status

Detection:
├─ kubectl get pods shows: ImagePullBackOff
└─ Events show: Failed to pull image

Potential Causes:
├─ Image doesn't exist in ACR
├─ ACR access denied (managed identity issue)
├─ Image tag incorrect
└─ Network connectivity blocked

Recovery:
├─ Verify image exists in ACR:
│  $ az acr repository show --name myacr --repository ems-backend
├─ Check kubelet identity permissions:
│  $ az role assignment list --assignee <kubelet-id>
├─ Verify deployment image tag:
│  $ kubectl describe deployment ems-backend | grep image
└─ If all correct: kubectl delete pod (triggers retry)
```

---

## Deployment Verification

### Pre-Deployment Checks

```bash
# Checklist before starting deployment
├─ [ ] GitHub Secrets configured
│  └─ AZURE_CREDENTIALS
│  └─ TF_VAR_SUBSCRIPTION_ID
│  └─ TF_VAR_ACR_NAME
│
├─ [ ] Repository branch protection enabled
│  └─ Require code review before merge
│  └─ Dismiss stale pull requests
│
├─ [ ] Helm chart validated
│  $ helm lint helm/employee-management-system/
│
├─ [ ] Docker images buildable locally
│  $ docker build -t test:backend -f docker/backend.Dockerfile .
│  $ docker build -t test:frontend -f docker/frontend.Dockerfile .
│
├─ [ ] AKS cluster accessible
│  $ az aks get-credentials --resource-group rg-aks-3tier-dev --name aks-ems-dev
│  $ kubectl get nodes
│
└─ [ ] Database connectivity
   $ psql -h pgemsdev.postgres.database.azure.com -U postgresadmin -d employee_db
```

### Post-Deployment Verification

```bash
# Checklist after deployment completes
├─ [ ] Pods are Running
│  $ kubectl get pods -n employee-management
│  # All pods show: Running, 1/1
│
├─ [ ] Health checks passing
│  $ kubectl describe pods -n employee-management | grep -A 5 "Probes"
│  # Liveness: OK
│  # Readiness: OK
│
├─ [ ] Services have endpoints
│  $ kubectl get endpoints -n employee-management
│  # ems-backend-service: 10.x.x.x:8080
│  # ems-frontend-service: 10.x.x.x:80
│
├─ [ ] ConfigMaps and Secrets mounted
│  $ kubectl get cm,secret -n employee-management
│  # ems-config ConfigMap present
│  # ems-secrets Secret present
│
├─ [ ] Ingress configured
│  $ kubectl get ingress -n employee-management
│  # ems-ingress has CLASS and HOSTS
│
├─ [ ] Test application endpoint
│  $ curl -k https://<ingress-url>/api/employees
│  # Returns 200 OK
│
└─ [ ] Database tables created
   $ psql -h ... -c "\dt" employee_db
   # Shows: public | employees | table
```

### Monitoring & Observability

```bash
# Real-time monitoring during deployment
├─ Watch pod startup
│  $ kubectl rollout status deployment/ems-backend -n employee-management --watch
│
├─ Stream logs
│  $ kubectl logs -f deployment/ems-backend -n employee-management
│
├─ Check resource usage
│  $ kubectl top nodes
│  $ kubectl top pods -n employee-management
│
├─ Monitor events
│  $ kubectl get events -n employee-management --sort-by='.lastTimestamp'
│
└─ Check HPA status
   $ kubectl get hpa -n employee-management
   # Shows: Current/Desired replicas, CPU %
```

---

## Azure RBAC Requirements

### Service Principal Roles (GitHub Actions)

```
Service Principal: github-actions-deployer

Required Roles:

1. Scope: /subscriptions/{subscription-id}
   ├─ Role: Contributor
   └─ Allows: Full AKS management, ACR operations

2. Scope: /subscriptions/.../resourceGroups/rg-aks-3tier-dev
   ├─ Role: Contributor
   └─ Allows: Resource group operations

3. Scope: /subscriptions/.../resourceGroups/.../providers/Microsoft.ContainerRegistry/registries/myacr
   ├─ Role: AcrPush
   └─ Allows: Push/pull images to ACR

4. Scope: /subscriptions/.../resourceGroups/.../providers/Microsoft.Compute/virtualMachines/jump-vm
   ├─ Role: Virtual Machine Contributor
   └─ Allows: VM run-command invocations
```

### JumpVM Managed Identity Roles

```
Managed Identity: aks-jumpvm-identity

Required Roles:

1. Scope: /subscriptions/.../resourceGroups/rg-aks-3tier-dev
   ├─ Role: Contributor
   └─ Allows: AKS credential retrieval, resource queries

2. Scope: /subscriptions/.../resourceGroups/.../providers/Microsoft.ContainerService/managedClusters/aks-ems-dev
   ├─ Role: Azure Kubernetes Service Contributor Role
   └─ Allows: get-credentials, kubectl access

3. Scope: /subscriptions/.../resourceGroups/.../providers/Microsoft.ContainerRegistry/registries/myacr
   ├─ Role: AcrPull
   └─ Allows: Pull images (for kubelet)

4. Scope: /subscriptions/.../resourceGroups/.../providers/Microsoft.Storage/storageAccounts/stghelm
   ├─ Role: Storage Blob Data Reader
   └─ Allows: Download Helm charts
```

### Kubelet Identity Roles (Pod Access)

```
Managed Identity: aks-kubelet-identity

Required Roles:

1. Scope: /subscriptions/.../resourceGroups/.../providers/Microsoft.ContainerRegistry/registries/myacr
   ├─ Role: AcrPull
   └─ Allows: Pods pull images from ACR

2. Scope: /subscriptions/.../resourceGroups/.../providers/Microsoft.KeyVault/vaults/ems-keyvault (optional)
   ├─ Role: Key Vault Secrets User
   └─ Allows: Pods read secrets from Key Vault
```

---

## GitHub Secrets Configuration

### Required Secrets

```yaml
# .github/workflows/deploy-private-aks.yml expects:

AZURE_CREDENTIALS:
  Type: Service Principal credentials (JSON)
  Format:
    {
      "clientId": "...",
      "clientSecret": "...",
      "subscriptionId": "...",
      "tenantId": "..."
    }
  Usage: Azure authentication
  
TF_VAR_SUBSCRIPTION_ID:
  Type: Azure Subscription ID
  Format: GUID (00000000-0000-0000-0000-000000000000)
  Usage: Terraform variable
  
TF_VAR_TENANT_ID:
  Type: Azure Tenant ID
  Format: GUID
  Usage: Azure AD authentication
  
TF_VAR_ACR_NAME:
  Type: Azure Container Registry name
  Format: String (alphanumeric, 5-50 chars)
  Usage: Docker image registry
  
TF_VAR_AKS_CLUSTER_NAME:
  Type: AKS cluster name
  Format: String
  Usage: Kubernetes cluster reference
  
TF_VAR_RESOURCE_GROUP_NAME:
  Type: Azure Resource Group name
  Format: String
  Usage: AKS resource group
  
HELM_CHART_STORAGE_ACCOUNT:
  Type: Storage account name
  Format: String (lowercase, alphanumeric)
  Usage: Helm chart storage location
  
HELM_CHART_STORAGE_CONTAINER:
  Type: Blob container name
  Format: String
  Usage: Helm chart blob container
```

### How to Add Secrets

```bash
# 1. Generate Service Principal (one-time setup)
$ az ad sp create-for-rbac \
    --name github-actions-deployer \
    --role Contributor \
    --scopes /subscriptions/<subscription-id>

# Output:
# {
#   "clientId": "...",
#   "clientSecret": "...",
#   "subscriptionId": "...",
#   "tenantId": "..."
# }

# 2. Add to GitHub Secrets (via GitHub UI or CLI)
$ gh secret set AZURE_CREDENTIALS -b "$(cat credentials.json)"
$ gh secret set TF_VAR_SUBSCRIPTION_ID -b "00000000-0000-0000-0000-000000000000"
$ gh secret set TF_VAR_TENANT_ID -b "..."
$ gh secret set TF_VAR_ACR_NAME -b "myacr"
$ gh secret set TF_VAR_AKS_CLUSTER_NAME -b "aks-ems-dev"
$ gh secret set TF_VAR_RESOURCE_GROUP_NAME -b "rg-aks-3tier-dev"
$ gh secret set HELM_CHART_STORAGE_ACCOUNT -b "stghelm..."
$ gh secret set HELM_CHART_STORAGE_CONTAINER -b "helm-charts"

# 3. Verify secrets (secrets are masked in output)
$ gh secret list
AZURE_CREDENTIALS      Updated 2026-06-16
TF_VAR_SUBSCRIPTION_ID Updated 2026-06-16
...
```

### Secret Rotation Policy

```
Credential Rotation Schedule:

Service Principal Secret:
├─ Rotation: Every 90 days
├─ Process:
│  1. Create new secret in Azure AD
│  2. Update GitHub Secret
│  3. Wait 24 hours (log monitoring)
│  4. Delete old secret
└─ Risk: Short window of both secrets valid (acceptable)

SSH Key (JumpVM):
├─ Rotation: Every 6 months
├─ Process:
│  1. Generate new key pair
│  2. Update JumpVM authorized_keys
│  3. Update local ~/.ssh/config
│  4. Delete old key
└─ Risk: New connections fail during rotation window

Database Password:
├─ Rotation: Every 6 months
├─ Process:
│  1. Set new password in Azure
│  2. Update Kubernetes Secret
│  3. Restart pods (pick up new password)
│  4. Verify connectivity
└─ Risk: Connection failures if timing wrong
```

---

## JumpVM Interaction Model

### Architecture

```
GitHub Actions (Public Cloud)
    │
    ├─ HTTPS/SSH (over internet)
    │
    ▼
Azure Control Plane (Regional)
    │
    ├─ Compute APIs
    │
    ▼
JumpVM (In VNet)
    │
    ├─ Private IP (10.0.3.0/24)
    ├─ No public IP
    ├─ Access via Azure Bastion or Run Command
    │
    ▼
Private AKS Cluster (In VNet)
    │
    └─ Private API Server (10.0.1.5:443)
```

### Communication Flow

```
1. GitHub Actions triggers deployment
   └─ Workflow step: "Deploy via Jump VM"

2. GitHub Actions invokes Azure REST API
   └─ Endpoint: /subscriptions/.../resourceGroups/.../providers/Microsoft.Compute/virtualMachines/jump-vm/runCommand

3. Azure authenticates request
   └─ Using: GitHub OIDC token (exchanged for Azure token)

4. Azure authorizes request
   └─ RBAC: GitHub Actions service principal has Contributor role

5. Azure queues command on JumpVM
   └─ Via: IMDS (Instance Metadata Service)

6. JumpVM executes command
   ├─ Command: bash script
   ├─ Environment: JumpVM shell session
   └─ Permissions: Root (security consideration)

7. JumpVM reaches out to private AKS
   └─ Network path: JumpVM IP (10.0.3.x) → AKS API (10.0.1.5)
   └─ Network isolation: Within VNet (no internet)

8. AKS validates request
   └─ Using: kubeconfig (certificate-based auth)

9. AKS responds with resources
   └─ kubectl operations succeed
   └─ Helm deployment completes

10. JumpVM returns output to GitHub Actions
    └─ stdout/stderr captured
    └─ Exit code returned
```

### Why JumpVM is Necessary

| Problem | Solution | Benefit |
|---------|----------|---------|
| **Private AKS Inaccessible from Internet** | JumpVM in same VNet | Direct access to private API server |
| **GitHub Actions is Public** | JumpVM acts as proxy | Decouples public CI/CD from private cluster |
| **No SSH from GitHub** | Azure Run Command | Remotely invoke commands safely |
| **Credentials Can't Leave GitHub** | Managed Identity on VM | VM authenticates, GitHub doesn't store creds |

### Security Model

```
Traditional (Risky):
GitHub Actions ← SSH credentials →   JumpVM ← kubectl credentials →   Private AKS
└─ Credentials passed through multiple systems
└─ Exposed to potential disclosure

Current (Secure):
GitHub Actions ← Azure IMDS → JumpVM (Managed Identity) ← kubectl credentials → Private AKS
├─ GitHub doesn't store JumpVM credentials
├─ JumpVM uses Managed Identity (token-based)
├─ JumpVM uses kubeconfig (certificate-based)
└─ Each service uses appropriate auth mechanism
```

---

## Technology Decision Rationale

### Why Managed Identity vs. Service Principal

**Managed Identity (Selected):**
```
Advantages:
✓ No credential storage (token from IMDS)
✓ Automatic token rotation (handled by Azure)
✓ No secret management overhead
✓ Better audit trail (Azure AD logs all token requests)
✓ No risk of credential exposure (no storage)
✓ Works seamlessly with Azure services

Disadvantages:
✗ Limited to Azure resources (not useful for external systems)
✗ Cannot be used outside Azure (e.g., self-hosted runners)
```

**Service Principal (Not Selected):**
```
Advantages:
✓ Works outside Azure (if credentials exported)
✓ Can be used for multiple purposes (multiple systems)

Disadvantages:
✗ Manual credential management (rotation, storage)
✗ Secret exposure risk (stored in config files, vaults)
✗ No automatic rotation (manual process)
✗ Difficult to audit (token requests not as visible)
✗ Shared secrets across systems (if reused)
```

### Why Helm vs. kubectl apply

**Helm (Selected):**
```
Advantages:
✓ Templating engine (loop, conditionals, functions)
✓ Values override mechanism (dev/prod configurations)
✓ Release versioning (rollback capability)
✓ Package management (chart dependencies)
✓ Community ecosystem (100K+ charts)
✓ Idempotent by design (safe to rerun)

Disadvantages:
✗ Additional tool to learn/maintain
✗ Slightly more complex than raw manifests
```

**kubectl apply (Not Selected):**
```
Advantages:
✓ Simple (direct Kubernetes API)
✓ No extra tools (kubectl only)

Disadvantages:
✗ No templating (must substitute manually)
✗ No values management (hardcoded or env vars)
✗ No versioning (can't rollback reliably)
✗ No package dependencies (manual orchestration)
✗ Difficult to manage multiple environments
```

### Why Azure Storage for Helm Charts

**Azure Storage (Selected):**
```
Advantages:
✓ Centralized storage (single source of truth)
✓ SAS URLs (time-limited, revocable access)
✓ Network isolation (Private endpoints available)
✓ Azure RBAC (fine-grained access control)
✓ Encryption (at rest and in transit)
✓ Audit logging (all access logged)
✓ Cost-effective (pay for usage, not fixed)

Disadvantages:
✗ Additional service to manage
✗ Network round-trip (vs. embedded in workflow)
```

**Embedded in Workflow (Not Selected):**
```
Advantages:
✓ Everything in one place (simpler)

Disadvantages:
✗ Large workflow artifacts (increases storage)
✗ No version history (overwrite previous)
✗ No access control (who can read)
✗ Not suitable for multi-team collaboration
```

---

## Troubleshooting Guide

### Common Issues & Resolution

| Issue | Symptom | Cause | Resolution |
|-------|---------|-------|-----------|
| **GitHub Secrets Not Found** | Workflow fails: "Null" values | Secrets not set in GitHub | `gh secret set AZURE_CREDENTIALS ...` |
| **Service Principal Expired** | 401 Unauthorized from ACR | Credentials expired (>90 days) | Rotate credentials, update GitHub Secrets |
| **AKS Inaccessible** | kubectl: "Unable to connect" | JumpVM can't reach private API | Verify Network Security Group rules, VNet routing |
| **Image Pull Failure** | ImagePullBackOff pod status | ACR access denied | Verify kubelet managed identity has AcrPull role |
| **Helm Deployment Timeout** | Deployment fails after 5m | Pods not becoming Ready | Check pod logs: `kubectl logs <pod>` |
| **Database Connection Failed** | Pod crashes with DB error | Firewall blocks PostgreSQL | Add AKS subnet to PostgreSQL firewall rules |
| **Helm Chart Not Found** | SAS URL expired or invalid | URL no longer valid | Re-run workflow (generates new SAS URL) |

### Debugging Checklist

```bash
# 1. GitHub Actions Logs
├─ GitHub UI: Actions tab → Workflow → Job logs
├─ Look for: Error messages, exit codes
└─ Action: Fix issues, re-run workflow

# 2. JumpVM Access
├─ Via Azure Bastion: Portal → VM → Connect → Bastion
├─ Command: `az vm run-command invoke ...`
└─ Check: Azure Activity Log for command execution

# 3. AKS Cluster
├─ Get credentials: `az aks get-credentials ...`
├─ Check nodes: `kubectl get nodes`
├─ Check pods: `kubectl get pods -A`
└─ Check events: `kubectl get events -A`

# 4. Container Logs
├─ View logs: `kubectl logs <pod> -n <namespace>`
├─ Stream logs: `kubectl logs -f <pod> -n <namespace>`
├─ View all logs: `kubectl logs <pod> --all-containers=true`
└─ Previous pod logs: `kubectl logs <pod> --previous`

# 5. Pod Describe
├─ Full pod details: `kubectl describe pod <pod> -n <namespace>`
├─ Look for: Events, warnings, failure messages
└─ Check: Probes, restarts, image pull errors

# 6. Network Connectivity
├─ From JumpVM to AKS: `telnet aks-ems-dev.xxx 443`
├─ From AKS pod to RDS: `telnet pgemsdev.postgres.database.azure.com 5432`
└─ From JumpVM to ACR: `curl https://myacr.azurecr.io`

# 7. Managed Identity
├─ JumpVM managed identity: `az login --identity`
├─ Check role assignments: `az role assignment list --assignee <mi-id>`
└─ Test ACR access: `az acr login --name myacr`
```

---

## Operational Runbooks

### Runbook 1: Deploy New Version

```
Objective: Deploy new application version to Private AKS

Prerequisites:
├─ Code changes committed to main branch
├─ All GitHub Secrets configured
└─ AKS cluster running and accessible

Procedure:
1. Push code to main branch
   $ git add .
   $ git commit -m "feat: new feature"
   $ git push origin main

2. Monitor GitHub Actions workflow
   ├─ Go to GitHub UI → Actions tab
   ├─ Select "Build, Push, and Deploy" workflow
   ├─ View real-time logs
   └─ Verify all jobs complete successfully

3. Verify deployment in AKS
   $ az aks get-credentials --resource-group rg-aks-3tier-dev --name aks-ems-dev
   $ kubectl rollout status deployment/ems-backend -n employee-management --watch
   $ kubectl rollout status deployment/ems-frontend -n employee-management --watch

4. Test application
   ├─ Get LoadBalancer IP: $ kubectl get svc -n employee-management
   ├─ Curl endpoint: $ curl http://<ip>/api/employees
   ├─ Check logs: $ kubectl logs -f deployment/ems-backend -n employee-management
   └─ Verify: Response code 200, data returned

Success Criteria:
✓ All pods Running (kubectl get pods shows 1/1)
✓ Health probes passing (no restart/unhealthy)
✓ Application responding to requests
✓ Logs show no errors

Rollback if needed:
$ helm rollback ems -n employee-management
# Reverts to previous working version immediately
```

### Runbook 2: Emergency Rollback

```
Objective: Quickly rollback deployment if critical issue discovered

Trigger: 
├─ Application not responsive
├─ High error rate detected
├─ Security vulnerability discovered
└─ Data corruption reported

Immediate Actions:
1. Assess severity
   ├─ Is user impact critical? YES → Proceed to rollback
   └─ Is user impact minor? → Investigate before rollback

2. Verify Helm release history
   $ helm history ems -n employee-management
   REVISION  UPDATED              STATUS     CHART
   1         Mon Jun 16 08:00:00  deployed   ems-1.0.0
   2         Mon Jun 16 10:00:00  deployed   ems-1.0.0  ← Current (problematic)
   3         Mon Jun 16 10:05:00  deployed   ems-1.0.0

3. Initiate rollback
   $ helm rollback ems 1 -n employee-management  # Rollback to revision 1
   # Output: Release ems has been rolled back to 1

4. Monitor rollback progress
   $ kubectl rollout status deployment/ems-backend -n employee-management --watch
   $ kubectl rollout status deployment/ems-frontend -n employee-management --watch

5. Verify functionality
   $ curl http://<service-ip>/api/employees  # Should work with old version
   $ kubectl logs -f deployment/ems-backend -n employee-management  # Check logs

6. Post-Incident
   ├─ Identify root cause of issue
   ├─ Fix code/configuration
   ├─ Test thoroughly in dev environment
   └─ Deploy fix (new release)

Expected Duration:
├─ Decision to rollback: 2-5 minutes
├─ Rollback execution: 1-2 minutes
├─ Verification: 2-3 minutes
└─ Total: ~5-10 minutes
```

### Runbook 3: Investigate Deployment Failure

```
Objective: Debug and resolve deployment pipeline failure

Initial Assessment:
1. Identify failed stage
   ├─ GitHub Actions UI → Actions tab
   ├─ Select failed workflow run
   ├─ Review step-by-step logs
   └─ Identify first failure

2. Common failure points:
   ├─ Code build (Maven/npm)
   ├─ Docker image creation
   ├─ ACR push
   ├─ Helm deployment
   └─ Pod startup

Investigation Process:

CASE A: Maven Build Failure
├─ Check build logs for compilation errors
├─ Run locally: mvn clean package
├─ Review dependencies (pom.xml changes)
├─ Action: Fix code, commit, re-push

CASE B: npm Build Failure
├─ Check build logs for errors
├─ Run locally: npm ci && npm run build
├─ Review dependencies (package.json changes)
├─ Action: Fix code, commit, re-push

CASE C: Docker Build Failure
├─ Check Docker build output in logs
├─ Run locally: docker build -t test -f docker/backend.Dockerfile .
├─ Verify Dockerfile syntax
├─ Action: Fix Dockerfile, commit, re-push

CASE D: ACR Push Failure
├─ Check GitHub Secrets (AZURE_CREDENTIALS, ACR_NAME)
├─ Verify ACR exists: az acr list
├─ Check ACR access: az acr login --name myacr
├─ Action: Update secrets or fix ACR access

CASE E: Helm Deployment Failure
├─ SSH to JumpVM and check manually:
│  $ helm status ems -n employee-management
│  $ kubectl describe deployment ems-backend -n employee-management
├─ Check pod events: $ kubectl get events -n employee-management
├─ View pod logs: $ kubectl logs -f deployment/ems-backend -n employee-management
└─ Action: Fix manifest/values, retry deployment

Resolution:
1. Identify root cause
2. Apply fix
3. Verify fix locally (if possible)
4. Commit and push
5. Monitor re-triggered workflow
6. Verify deployment success
```

---

## Monitoring & Alerting

### What to Monitor

```
Deployment Pipeline:
├─ Workflow duration (should be ~8 minutes)
├─ Failure rate (should be < 5%)
├─ Build cache hit rate (should be > 50%)
└─ ACR push success rate (should be 100%)

Application:
├─ Pod count (should match replicas)
├─ Error rate (should be < 1%)
├─ Response time (p95 < 500ms)
├─ CPU usage (should be < 60%)
├─ Memory usage (should be < 75%)
└─ Disk space (should be > 20% free)

Kubernetes:
├─ Node status (all Ready)
├─ Pod restart count (should be 0)
├─ Pending pods (should be 0)
├─ Network errors (should be 0)
└─ API server latency (should be < 100ms)

Azure:
├─ ACR storage usage
├─ AKS cluster health
├─ PostgreSQL connection count
├─ Network throughput
└─ Cost tracking
```

### Alert Thresholds

```
CRITICAL Alerts (immediate action):
├─ Pod CrashLoopBackOff > 5 minutes
├─ All pods NotReady > 2 minutes
├─ Database connection failed
├─ Out of disk space
└─ Network connectivity lost

WARNING Alerts (investigate within 30 min):
├─ Pod restart count > 3
├─ CPU usage > 80%
├─ Memory usage > 85%
├─ Error rate > 5%
└─ Response time p95 > 1s

INFO Alerts (track):
├─ Deployment completed
├─ Deployment started
├─ Pod added to service
└─ Pod removed from service
```

---

## Conclusion

This operational deployment document details the complete CI/CD pipeline from code commit to running application in Private AKS. The pipeline emphasizes:

✅ **Security:** Zero-trust network, managed identities, RBAC
✅ **Reliability:** Automated verification, health checks, rollback capability
✅ **Auditability:** Git history, Helm versioning, Azure Activity Log
✅ **Efficiency:** Parallel builds, caching, automated cleanup
✅ **Maintainability:** Infrastructure-as-code, declarative deployments

The deployment typically completes in **~8 minutes**, with comprehensive error handling and recovery mechanisms.

---

**Document prepared for:** DevOps Engineers, SREs, Release Managers  
**Last Updated:** June 2026  
**Version:** 1.0
