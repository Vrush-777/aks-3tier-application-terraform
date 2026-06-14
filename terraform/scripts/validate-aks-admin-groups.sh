#!/usr/bin/env bash
# ============================================================================
# validate-aks-admin-groups.sh
# ============================================================================
# Post-deployment validation script that verifies AKS Entra admin groups
# are properly configured after Terraform apply.
#
# Usage:
#   ./validate-aks-admin-groups.sh <resource-group> <aks-cluster-name>
#
# Exit codes:
#   0 - AKS admin groups are properly configured
#   1 - AKS cluster not found
#   2 - adminGroupObjectIDs is null or empty (CRITICAL)
# ============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Validate arguments
# ---------------------------------------------------------------------------
if [[ $# -lt 2 ]]; then
  echo "ERROR: Missing arguments."
  echo "Usage: $0 <resource-group> <aks-cluster-name>"
  exit 1
fi

RESOURCE_GROUP="$1"
AKS_CLUSTER_NAME="$2"

echo "=========================================="
echo "AKS Entra Admin Group Validation"
echo "=========================================="
echo "Resource Group: ${RESOURCE_GROUP}"
echo "AKS Cluster:    ${AKS_CLUSTER_NAME}"
echo "=========================================="

# ---------------------------------------------------------------------------
# Step 1: Verify the AKS cluster exists
# ---------------------------------------------------------------------------
echo ""
echo "[1/3] Checking AKS cluster exists..."

if ! az aks show \
  --resource-group "${RESOURCE_GROUP}" \
  --name "${AKS_CLUSTER_NAME}" \
  --output none 2>/dev/null; then
  echo "ERROR: AKS cluster '${AKS_CLUSTER_NAME}' not found in resource group '${RESOURCE_GROUP}'."
  exit 1
fi

echo "  ✓ AKS cluster exists."

# ---------------------------------------------------------------------------
# Step 2: Query the adminGroupObjectIDs from the AAD profile
# ---------------------------------------------------------------------------
echo ""
echo "[2/3] Querying aadProfile.adminGroupObjectIDs..."

ADMIN_GROUP_IDS=$(az aks show \
  --resource-group "${RESOURCE_GROUP}" \
  --name "${AKS_CLUSTER_NAME}" \
  --query "aadProfile.adminGroupObjectIDs" \
  --output json 2>/dev/null) || {
    echo "ERROR: Failed to query AKS AAD profile."
    exit 1
}

echo "  Raw result: ${ADMIN_GROUP_IDS}"

# ---------------------------------------------------------------------------
# Step 3: Validate that adminGroupObjectIDs is NOT null and NOT empty
# ---------------------------------------------------------------------------
echo ""
echo "[3/3] Validating admin group configuration..."

# Check for null
if [[ "${ADMIN_GROUP_IDS}" == "null" ]]; then
  echo ""
  echo "=========================================="
  echo "❌ FAILURE: AKS AAD admin groups are NULL"
  echo "=========================================="
  echo ""
  echo "The AKS cluster '${AKS_CLUSTER_NAME}' has NO Entra administrator"
  echo "groups configured in its AAD profile."
  echo ""
  echo "This means NO ONE can authenticate to this cluster — kubectl"
  echo "commands will fail with 'Forbidden' errors even though"
  echo "authentication (az login) succeeds."
  echo ""
  echo "ROOT CAUSE:"
  echo "  azure_active_directory_role_based_access_control block"
  echo "  admin_group_object_ids was not set during AKS creation."
  echo ""
  echo "RESOLUTION:"
  echo "  1. Ensure aks_admin_group_object_ids contains at least one"
  echo "     valid Entra group Object ID in terraform.tfvars."
  echo "  2. Re-run terraform apply to update the AKS cluster's"
  echo "     AAD profile with the correct admin groups."
  echo ""
  exit 2
fi

# Check for empty array
EMPTY_CHECK=$(echo "${ADMIN_GROUP_IDS}" | python3 -c "
import sys, json
data = json.load(sys.stdin)
if isinstance(data, list) and len(data) > 0:
    print('configured')
else:
    print('empty')
" 2>/dev/null) || {
  # Fallback check if python3 is not available
  if [[ "${ADMIN_GROUP_IDS}" == "[]" ]]; then
    echo "  ✓ Detected empty array via bash check"
    EMPTY_CHECK="empty"
  fi
}

if [[ "${EMPTY_CHECK}" == "empty" ]]; then
  echo ""
  echo "=========================================="
  echo "❌ FAILURE: AKS AAD admin groups are EMPTY"
  echo "=========================================="
  echo ""
  echo "The AKS cluster '${AKS_CLUSTER_NAME}' has an empty list of"
  echo "Entra administrator groups."
  echo ""
  echo "This means NO ONE can authenticate to this cluster."
  echo ""
  exit 2
fi

# ---------------------------------------------------------------------------
# Success
# ---------------------------------------------------------------------------
echo ""
echo "=========================================="
echo "✅ SUCCESS: AKS admin groups are configured"
echo "=========================================="
echo ""
echo "Configured admin group Object IDs:"
echo "${ADMIN_GROUP_IDS}" | python3 -m json.tool 2>/dev/null || echo "${ADMIN_GROUP_IDS}"
echo ""
echo "The following administrators can access the cluster:"
for group_id in $(echo "${ADMIN_GROUP_IDS}" | python3 -c "
import sys, json
for gid in json.load(sys.stdin):
    print(gid)
" 2>/dev/null); do
  echo "  - ${group_id}"
done
echo ""
echo "=========================================="
echo ""

exit 0