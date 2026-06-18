# Deploy.sh Script - Receiving All 6 Arguments

## Overview

This guide shows what your `deploy.sh` script on the Jump VM should look like to properly receive and validate all 6 arguments from GitHub Actions.

---

## Expected Arguments

Your deploy.sh should expect to receive exactly 6 arguments in this order:

| Position | Name | Type | Example |
|----------|------|------|---------|
| 1 | RESOURCE_GROUP | String | `aks-3tier-dev` |
| 2 | AKS_CLUSTER | String | `aks-prod-cluster` |
| 3 | IMAGE_TAG | String | `a1b2c3d4` |
| 4 | ACR_SERVER | String | `aksregistry.azurecr.io` |
| 5 | SUBSCRIPTION_ID | String | `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` |
| 6 | CHART_ARCHIVE | Path | `/tmp/deploy-artifacts-12345.tar.gz` |

---

## Recommended deploy.sh Template

Place this at `/opt/deploy/deploy.sh` on your Jump VM:

```bash
#!/bin/bash
################################################################################
# deploy.sh - Deploy Helm charts to private AKS cluster
# 
# Usage: ./deploy.sh RESOURCE_GROUP AKS_CLUSTER IMAGE_TAG ACR_SERVER \
#                    SUBSCRIPTION_ID CHART_ARCHIVE
#
# Arguments:
#   1: RESOURCE_GROUP      - Azure resource group name
#   2: AKS_CLUSTER         - AKS cluster name  
#   3: IMAGE_TAG           - Docker image tag (usually git SHA)
#   4: ACR_SERVER          - Azure Container Registry FQDN
#   5: SUBSCRIPTION_ID     - Azure subscription ID
#   6: CHART_ARCHIVE       - Path to helm chart archive (tar.gz)
#
# Environment:
#   HELM_REPO_NAME         - Helm repo name (default: "ems-repo")
#   CHART_NAME             - Chart directory name (default: "employee-management-system")
#   NAMESPACE              - K8s namespace (default: "employee-management")
#   KUBECONFIG             - K8s config file (default: ~/.kube/config)
#   ACR_USERNAME           - ACR username for login
#   ACR_PASSWORD           - ACR password for login
#
################################################################################

set -e
set -o pipefail

# ═══════════════════════════════════════════════════════════════════════════
# Configuration
# ═══════════════════════════════════════════════════════════════════════════

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
LOG_FILE="${LOG_DIR}/deployment-$(date +%Y%m%d-%H%M%S).log"
TEMP_DIR="${SCRIPT_DIR}/temp"

# Defaults
HELM_REPO_NAME="${HELM_REPO_NAME:-ems-repo}"
CHART_NAME="${CHART_NAME:-employee-management-system}"
NAMESPACE="${NAMESPACE:-employee-management}"
KUBECONFIG="${KUBECONFIG:-${HOME}/.kube/config}"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ═══════════════════════════════════════════════════════════════════════════
# Functions
# ═══════════════════════════════════════════════════════════════════════════

log() {
  echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $*" | tee -a "${LOG_FILE}"
}

log_success() {
  echo -e "${GREEN}[✓]${NC} $*" | tee -a "${LOG_FILE}"
}

log_error() {
  echo -e "${RED}[✗ ERROR]${NC} $*" | tee -a "${LOG_FILE}"
}

log_warning() {
  echo -e "${YELLOW}[⚠ WARNING]${NC} $*" | tee -a "${LOG_FILE}"
}

# ═══════════════════════════════════════════════════════════════════════════
# Argument Validation
# ═══════════════════════════════════════════════════════════════════════════

# Ensure log directory exists
mkdir -p "${LOG_DIR}" "${TEMP_DIR}"

log "═══════════════════════════════════════════════════════════════════════════"
log "AKS Deployment Script Started"
log "═══════════════════════════════════════════════════════════════════════════"
log ""

# ✅ CRITICAL: Verify we received exactly 6 arguments
log "Validating arguments..."
log "Total arguments received: $#"
echo ""

# Print all arguments for debugging
log "Arguments received:"
for i in {1..6}; do
  var_name="arg_${i}"
  eval "value=\$${i}"
  if [ -z "$value" ]; then
    log_error "Argument ${i} is EMPTY"
  else
    # Hide sensitive info in logs
    case $i in
      5)  # SUBSCRIPTION_ID - show first 8 chars only
        visible=$(echo "${value}" | cut -c1-8)"...$(echo "${value}" | cut -c-8)"
        log "  Arg ${i}: ${visible}"
        ;;
      *)
        log "  Arg ${i}: ${value}"
        ;;
    esac
  fi
done
echo ""

# Validate argument count
if [ $# -ne 6 ]; then
  log_error "Expected 6 arguments, but received $#"
  echo ""
  echo "Usage: $0 RESOURCE_GROUP AKS_CLUSTER IMAGE_TAG ACR_SERVER SUBSCRIPTION_ID CHART_ARCHIVE"
  echo ""
  echo "Example:"
  echo "  $0 my-rg my-cluster abc1234 registry.azurecr.io 12345678-1234-1234-1234-123456789012 /tmp/chart.tar.gz"
  exit 1
fi

# Assign arguments to named variables
RESOURCE_GROUP="$1"
AKS_CLUSTER="$2"
IMAGE_TAG="$3"
ACR_SERVER="$4"
SUBSCRIPTION_ID="$5"
CHART_ARCHIVE="$6"

# ═══════════════════════════════════════════════════════════════════════════
# Argument Verification
# ═══════════════════════════════════════════════════════════════════════════

log "Verifying arguments..."
log ""

# Check each argument
ERROR_COUNT=0

if [ -z "${RESOURCE_GROUP}" ]; then
  log_error "RESOURCE_GROUP is empty"
  ((ERROR_COUNT++))
else
  log_success "RESOURCE_GROUP: ${RESOURCE_GROUP}"
fi

if [ -z "${AKS_CLUSTER}" ]; then
  log_error "AKS_CLUSTER is empty"
  ((ERROR_COUNT++))
else
  log_success "AKS_CLUSTER: ${AKS_CLUSTER}"
fi

if [ -z "${IMAGE_TAG}" ]; then
  log_error "IMAGE_TAG is empty"
  ((ERROR_COUNT++))
else
  log_success "IMAGE_TAG: ${IMAGE_TAG}"
fi

if [ -z "${ACR_SERVER}" ]; then
  log_error "ACR_SERVER is empty"
  ((ERROR_COUNT++))
else
  log_success "ACR_SERVER: ${ACR_SERVER}"
fi

if [ -z "${SUBSCRIPTION_ID}" ]; then
  log_error "SUBSCRIPTION_ID is empty"
  ((ERROR_COUNT++))
else
  SUB_SHORT=$(echo "${SUBSCRIPTION_ID}" | cut -c1-8)"..."
  log_success "SUBSCRIPTION_ID: ${SUB_SHORT}"
fi

if [ -z "${CHART_ARCHIVE}" ]; then
  log_error "CHART_ARCHIVE is empty"
  ((ERROR_COUNT++))
else
  if [ ! -f "${CHART_ARCHIVE}" ]; then
    log_error "CHART_ARCHIVE file not found: ${CHART_ARCHIVE}"
    ((ERROR_COUNT++))
  else
    ARCHIVE_SIZE=$(stat -f%z "${CHART_ARCHIVE}" 2>/dev/null || stat -c%s "${CHART_ARCHIVE}")
    log_success "CHART_ARCHIVE: ${CHART_ARCHIVE} (${ARCHIVE_SIZE} bytes)"
  fi
fi

echo ""

if [ ${ERROR_COUNT} -gt 0 ]; then
  log_error "Argument validation failed with ${ERROR_COUNT} error(s)"
  exit 1
fi

log_success "All arguments validated"
echo ""

# ═══════════════════════════════════════════════════════════════════════════
# Environment Setup
# ═══════════════════════════════════════════════════════════════════════════

log "Setting up environment..."

# Set subscription context
log "Setting Azure subscription context..."
az account set --subscription "${SUBSCRIPTION_ID}" 2>&1 | tee -a "${LOG_FILE}"
log_success "Subscription context set"

# Get AKS credentials
log "Obtaining AKS credentials..."
az aks get-credentials \
  --resource-group "${RESOURCE_GROUP}" \
  --name "${AKS_CLUSTER}" \
  --overwrite-existing \
  2>&1 | tee -a "${LOG_FILE}"
log_success "AKS credentials obtained"

echo ""

# ═══════════════════════════════════════════════════════════════════════════
# Extract Chart Archive
# ═══════════════════════════════════════════════════════════════════════════

log "Extracting chart archive..."

EXTRACT_DIR="${TEMP_DIR}/helm-charts-$(date +%s)"
mkdir -p "${EXTRACT_DIR}"

tar -xzf "${CHART_ARCHIVE}" -C "${EXTRACT_DIR}" 2>&1 | tee -a "${LOG_FILE}"

log_success "Chart archive extracted to: ${EXTRACT_DIR}"

# Find the chart directory
CHART_DIR=$(find "${EXTRACT_DIR}" -maxdepth 2 -name "${CHART_NAME}" -type d | head -1)

if [ -z "${CHART_DIR}" ]; then
  log_error "Could not find chart directory: ${CHART_NAME}"
  log "Archive contents:"
  find "${EXTRACT_DIR}" -maxdepth 3
  exit 1
fi

log_success "Chart directory found: ${CHART_DIR}"
echo ""

# ═══════════════════════════════════════════════════════════════════════════
# Kubernetes Namespace
# ═══════════════════════════════════════════════════════════════════════════

log "Checking Kubernetes namespace..."

if kubectl get namespace "${NAMESPACE}" >/dev/null 2>&1; then
  log_success "Namespace '${NAMESPACE}' exists"
else
  log "Creating namespace '${NAMESPACE}'..."
  kubectl create namespace "${NAMESPACE}" 2>&1 | tee -a "${LOG_FILE}"
  log_success "Namespace created"
fi

echo ""

# ═══════════════════════════════════════════════════════════════════════════
# Helm Deployment
# ═══════════════════════════════════════════════════════════════════════════

log "Deploying with Helm..."
log ""

# Set values for Helm
HELM_VALUES="image.tag=${IMAGE_TAG},image.registry=${ACR_SERVER}"

log "Helm deployment values:"
log "  Chart: ${CHART_DIR}"
log "  Namespace: ${NAMESPACE}"
log "  Release: ${HELM_REPO_NAME}"
log "  Values: ${HELM_VALUES}"
log ""

# Deploy with Helm
helm upgrade --install "${HELM_REPO_NAME}" "${CHART_DIR}" \
  --namespace "${NAMESPACE}" \
  --set ${HELM_VALUES} \
  --wait \
  --timeout 5m \
  2>&1 | tee -a "${LOG_FILE}"

HELM_RESULT=$?

if [ ${HELM_RESULT} -eq 0 ]; then
  log_success "Helm deployment completed successfully"
else
  log_error "Helm deployment failed with exit code ${HELM_RESULT}"
  exit 1
fi

echo ""

# ═══════════════════════════════════════════════════════════════════════════
# Verification
# ═══════════════════════════════════════════════════════════════════════════

log "Verifying deployment..."
echo ""

# Check pod status
log "Pod status:"
kubectl get pods -n "${NAMESPACE}" --no-headers 2>&1 | tee -a "${LOG_FILE}"
echo ""

# Check services
log "Services:"
kubectl get svc -n "${NAMESPACE}" --no-headers 2>&1 | tee -a "${LOG_FILE}"
echo ""

# Check Helm release
log "Helm release status:"
helm status "${HELM_REPO_NAME}" -n "${NAMESPACE}" 2>&1 | tee -a "${LOG_FILE}"
echo ""

log_success "Deployment verification completed"
echo ""

# ═══════════════════════════════════════════════════════════════════════════
# Cleanup
# ═══════════════════════════════════════════════════════════════════════════

log "Cleaning up temporary files..."
rm -rf "${EXTRACT_DIR}"
log_success "Cleanup completed"
echo ""

# ═══════════════════════════════════════════════════════════════════════════
# Final Status
# ═══════════════════════════════════════════════════════════════════════════

log "═══════════════════════════════════════════════════════════════════════════"
log "✅ Deployment Completed Successfully"
log "═══════════════════════════════════════════════════════════════════════════"
log "Deployment status file: ${LOG_FILE}"
echo ""

# ✅ CRITICAL: Print success marker that GitHub Actions checks for
echo "DEPLOYMENT_STATUS=SUCCESS"

exit 0
```

---

## Key Features of This Script

### 1. **Argument Validation (Lines 110-165)** ✅
```bash
# Verify we received exactly 6 arguments
if [ $# -ne 6 ]; then
  log_error "Expected 6 arguments, but received $#"
  exit 1
fi
```

**Why it matters:**
- Fails immediately if wrong number of arguments
- Prevents cryptic errors later
- Visible in logs

### 2. **Detailed Argument Printing (Lines 123-134)** ✅
```bash
log "Arguments received:"
for i in {1..6}; do
  # Print each argument for debugging
done
```

**Why it matters:**
- Shows exactly what GitHub Actions passed
- Easy to spot missing/empty arguments
- Visible in GitHub Actions logs

### 3. **Named Variable Assignment (Lines 152-157)** ✅
```bash
RESOURCE_GROUP="$1"
AKS_CLUSTER="$2"
IMAGE_TAG="$3"
ACR_SERVER="$4"
SUBSCRIPTION_ID="$5"
CHART_ARCHIVE="$6"
```

**Why it matters:**
- Makes code readable
- Prevents confusion about which argument is which
- Easy to maintain

### 4. **Individual Argument Verification (Lines 162-200)** ✅
```bash
if [ -z "${CHART_ARCHIVE}" ]; then
  log_error "CHART_ARCHIVE is empty"
else
  if [ ! -f "${CHART_ARCHIVE}" ]; then
    log_error "CHART_ARCHIVE file not found"
  fi
fi
```

**Why it matters:**
- Each argument is validated
- File existence checked
- Clear error messages
- Early detection of problems

### 5. **Success Marker (Line 373)** ✅
```bash
echo "DEPLOYMENT_STATUS=SUCCESS"
```

**Why it matters:**
- GitHub Actions workflow checks for this line
- Distinguishes successful deployment from silent failures
- Must be printed to stdout

---

## Installation Instructions

### Step 1: Create Deploy Directory
```bash
# SSH into Jump VM
ssh jumpvm@your-jump-vm-ip

# Create deployment directory
sudo mkdir -p /opt/deploy/logs
sudo mkdir -p /opt/deploy/temp

# Change ownership
sudo chown jumpvm:jumpvm /opt/deploy -R
```

### Step 2: Create deploy.sh
```bash
# Create the script
cat > /opt/deploy/deploy.sh <<'EOF'
# ... paste the script above ...
EOF

# Make it executable
chmod +x /opt/deploy/deploy.sh

# Verify
ls -la /opt/deploy/deploy.sh
```

### Step 3: Test the Script
```bash
# Create a test chart archive
tar -czf /tmp/test-chart.tar.gz your-helm-chart/

# Run with test arguments
/opt/deploy/deploy.sh \
  "test-rg" \
  "test-cluster" \
  "test-tag" \
  "test.azurecr.io" \
  "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" \
  "/tmp/test-chart.tar.gz"

# Check exit code
echo "Exit code: $?"
```

---

## Expected Output

When deploy.sh is called with all 6 arguments correctly:

```
[2024-01-15 10:30:45] ═══════════════════════════════════════════════════════════════════════════
[2024-01-15 10:30:45] AKS Deployment Script Started
[2024-01-15 10:30:45] ═══════════════════════════════════════════════════════════════════════════
[2024-01-15 10:30:45] 
[2024-01-15 10:30:45] Validating arguments...
[2024-01-15 10:30:45] Total arguments received: 6
[2024-01-15 10:30:45] 
[2024-01-15 10:30:45] Arguments received:
[2024-01-15 10:30:45]   Arg 1: aks-3tier-dev
[2024-01-15 10:30:45]   Arg 2: aks-prod-cluster
[2024-01-15 10:30:45]   Arg 3: a1b2c3d4
[2024-01-15 10:30:45]   Arg 4: aksregistry.azurecr.io
[2024-01-15 10:30:45]   Arg 5: 12345678...
[2024-01-15 10:30:45]   Arg 6: /tmp/deploy-artifacts-123456.tar.gz
[✓] All arguments validated
...
[✓] Deployment Completed Successfully
DEPLOYMENT_STATUS=SUCCESS
```

---

## Troubleshooting

### Problem: "Expected 6 arguments, but received X"

**Solution:** GitHub Actions workflow is not passing all arguments
- Check GitHub Actions logs for "Arg 6"
- Verify REMOTE_CHART_ARCHIVE is not empty
- Use the debugging output to identify which argument is missing

### Problem: "CHART_ARCHIVE is empty"

**Solution:** Argument 6 is being passed but is empty
- Check GitHub Actions logs for REMOTE_CHART_ARCHIVE value
- Verify base64 decoding worked
- Check that sed substitution completed

### Problem: "CHART_ARCHIVE file not found: /tmp/deploy-artifacts-..."

**Solution:** Archive file doesn't exist on Jump VM
- Verify base64 decode completed successfully
- Check /tmp directory: `ls -la /tmp/deploy-artifacts-*`
- Review Jump VM logs: `tail -50 /opt/deploy/logs/deployment-*.log`

### Problem: "Could not find chart directory"

**Solution:** Chart directory structure in archive is different than expected
- Extract archive manually: `tar -tzf /tmp/deploy-artifacts-*.tar.gz | head -20`
- Verify directory structure matches CHART_NAME variable
- Update script or archive structure as needed

---

## Summary

This deploy.sh script:
1. ✅ Validates it receives exactly 6 arguments
2. ✅ Prints all arguments for debugging
3. ✅ Verifies each argument is not empty
4. ✅ Checks that the chart archive file exists
5. ✅ Extracts the chart archive
6. ✅ Deploys with Helm
7. ✅ Verifies deployment success
8. ✅ Prints "DEPLOYMENT_STATUS=SUCCESS" marker

When combined with the fixed GitHub Actions workflow, all 6 arguments will reach deploy.sh correctly.

