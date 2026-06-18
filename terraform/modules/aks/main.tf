# =========================================================
# AKS MODULE - PRIVATE CLUSTER + AAD RBAC + VM ACCESS FIX
# =========================================================

resource "azurerm_kubernetes_cluster" "aks" {

  # ---------------------------------------------------------
  # SAFETY CHECK: ENSURE ENTRA ADMIN GROUP EXISTS
  # ---------------------------------------------------------
  lifecycle {
    precondition {
      condition     = length(var.admin_group_object_ids) > 0
      error_message = "Fatal: AKS cluster requires at least one Entra admin group."
    }
  }

  name                = var.aks_cluster_name
  location            = var.location
  resource_group_name = var.resource_group_name
  kubernetes_version  = var.kubernetes_version
  dns_prefix          = var.aks_cluster_name

  # ---------------------------------------------------------
  # DEFAULT NODE POOL
  # ---------------------------------------------------------
  default_node_pool {
    name            = var.default_node_pool_name
    node_count      = var.default_node_pool_count
    vm_size         = var.default_node_pool_vm_size
    vnet_subnet_id  = var.aks_subnet_id
    os_disk_size_gb = var.os_disk_size_gb

    enable_auto_scaling = var.enable_auto_scaling
    min_count           = var.min_count
    max_count           = var.max_count

    zones        = var.availability_zones
    node_labels  = var.node_labels
    node_taints  = var.node_taints
  }

  # ---------------------------------------------------------
  # NETWORK PROFILE
  # ---------------------------------------------------------
  network_profile {
    network_plugin    = var.network_plugin
    network_policy    = var.network_policy
    dns_service_ip    = var.dns_service_ip != "" ? var.dns_service_ip : null
    service_cidr      = var.service_cidr != "" ? var.service_cidr : null
    load_balancer_sku = "standard"
    outbound_type     = var.outbound_type
  }

  # ---------------------------------------------------------
  # PRIVATE CLUSTER CONFIG
  # ---------------------------------------------------------
  private_cluster_enabled = var.private_cluster_enabled
  private_dns_zone_id     = var.private_dns_zone_id != "" ? var.private_dns_zone_id : null

  # ---------------------------------------------------------
  # MANAGED IDENTITY (AKS CONTROL PLANE)
  # ---------------------------------------------------------
  identity {
    type         = "UserAssigned"
    identity_ids = [var.aks_managed_identity_id]
  }

  # ---------------------------------------------------------
  # KUBELET IDENTITY
  # ---------------------------------------------------------
  kubelet_identity {
    client_id                 = var.kubelet_client_id
    object_id                 = var.kubelet_object_id
    user_assigned_identity_id = var.kubelet_identity_id
  }

  # ---------------------------------------------------------
  # RBAC ENABLED
  # ---------------------------------------------------------
  role_based_access_control_enabled = true

  azure_active_directory_role_based_access_control {
    managed                = true
    admin_group_object_ids = var.admin_group_object_ids
  }

  # ---------------------------------------------------------
  # AGIC INTEGRATION
  # ---------------------------------------------------------
  ingress_application_gateway {
    gateway_id = var.appgw_id
  }

  http_application_routing_enabled = false

  # ---------------------------------------------------------
  # UPGRADE CHANNELS
  # ---------------------------------------------------------
  automatic_channel_upgrade = var.automatic_channel_upgrade
  node_os_channel_upgrade   = var.node_os_channel_upgrade

  # ---------------------------------------------------------
  # SECURITY
  # ---------------------------------------------------------
  local_account_disabled = false

  tags = merge(
    var.common_tags,
    {
      Name = var.aks_cluster_name
    }
  )

  depends_on = [
    var.kubelet_role_assignment_id,
    var.aks_role_assignment_id
  ]
}

# =========================================================
# FIX: GRANT VM MANAGED IDENTITY AKS RBAC ACCESS
# =========================================================
resource "azurerm_role_assignment" "aks_vm_cluster_admin" {
  scope = azurerm_kubernetes_cluster.aks.id

  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"

  # MUST be principalId of VM managed identity
  principal_id = var.aks_managed_identity_principal_id
}

# =========================================================
# ADDITIONAL NODE POOLS
# =========================================================
resource "azurerm_kubernetes_cluster_node_pool" "additional_node_pool" {

  for_each = var.additional_node_pools

  name                  = each.key
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks.id

  node_count      = each.value.node_count
  vm_size         = each.value.vm_size
  zones           = var.availability_zones
  vnet_subnet_id  = var.aks_subnet_id
  os_disk_size_gb = each.value.os_disk_size_gb

  enable_auto_scaling = each.value.enable_auto_scaling
  min_count           = each.value.min_count
  max_count           = each.value.max_count

  node_labels = each.value.node_labels
  node_taints = each.value.node_taints

  priority        = each.value.priority
  eviction_policy = each.value.priority == "Spot" ? "Delete" : null
  spot_max_price  = each.value.priority == "Spot" ? each.value.spot_max_price : null

  tags = merge(
    var.common_tags,
    {
      Name = each.key
    }
  )
}