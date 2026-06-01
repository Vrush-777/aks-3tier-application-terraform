# AKS Module - main.tf
# Creates a private AKS cluster with managed identity and AGIC support

resource "azurerm_kubernetes_cluster" "aks" {
  name                = var.aks_cluster_name
  location            = var.location
  resource_group_name = var.resource_group_name
  kubernetes_version  = var.kubernetes_version
  dns_prefix          = var.aks_cluster_name

  # Default Node Pool
  default_node_pool {
    name                = var.default_node_pool_name
    node_count          = var.default_node_pool_count
    vm_size             = var.default_node_pool_vm_size
    vnet_subnet_id      = var.aks_subnet_id
    os_disk_size_gb     = var.os_disk_size_gb
    
    # Auto-scaling
    enable_auto_scaling = var.enable_auto_scaling
    min_count          = var.min_count
    max_count          = var.max_count
    
    # Availability zones
    availability_zones  = var.availability_zones

    # Node labels
    node_labels         = var.node_labels

    # Node taints
    node_taints         = var.node_taints
  }

  # Network settings - Azure CNI with managed identity
  network_profile {
    network_plugin      = var.network_plugin  # "azure" for Azure CNI
    network_policy      = var.network_policy
    dns_service_ip      = var.dns_service_ip
    docker_bridge_cidr  = var.docker_bridge_cidr
    service_cidr        = var.service_cidr
    load_balancer_sku   = "standard"
    outbound_type       = var.outbound_type
  }

  # Private cluster configuration
  private_cluster_enabled             = var.private_cluster_enabled
  private_dns_zone_id                 = var.private_dns_zone_id

  # Managed Identity
  identity {
    type                      = "UserAssigned"
    identity_ids              = [var.aks_managed_identity_id]
  }

  # Kubelet Managed Identity
  kubelet_identity {
    client_id                 = var.kubelet_client_id
    object_id                 = var.kubelet_object_id
    user_assigned_identity_id = var.kubelet_identity_id
  }

  # RBAC Settings
  role_based_access_control_enabled = true

  azure_active_directory_role_based_access_control {
    managed                = true
    admin_group_object_ids = var.admin_group_object_ids
  }

  # Ingress - Application Gateway Integration
  ingress_application_gateway {
    enabled                   = true
    gateway_id                = var.appgw_id
    gateway_name              = var.appgw_name
    subnet_cidr               = var.appgw_subnet_cidr
    subnet_id                 = var.appgw_subnet_id
  }

  # Add-ons
  http_application_routing_enabled = false
  
  addon_profile {
    azure_policy {
      enabled = var.enable_azure_policy
    }
    
    kube_dashboard {
      enabled = false  # Dashboard is deprecated
    }
  }

  # Auto-upgrade channel
  automatic_channel_upgrade = var.automatic_channel_upgrade

  # Node OS Channel
  node_os_channel_upgrade = var.node_os_channel_upgrade

  # Maintenance Window (optional)
  dynamic "maintenance_window" {
    for_each = var.enable_maintenance_window ? [1] : []
    content {
      day_of_week = var.maintenance_window_day
      duration    = var.maintenance_window_duration
      start_time  = var.maintenance_window_start_time
    }
  }

  # Maintenance Window - Node OS
  dynamic "maintenance_window_node_os" {
    for_each = var.enable_node_os_maintenance_window ? [1] : []
    content {
      day_of_week = var.node_os_maintenance_window_day
      duration    = var.node_os_maintenance_window_duration
      start_time  = var.node_os_maintenance_window_start_time
    }
  }

  # Pod Security Policy (deprecated but can be configured)
  # Shift to use Azure Policy instead

  # Local Account Disabled
  local_account_disabled = true

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

# Additional Node Pool (optional GPU or spot VMs)
resource "azurerm_kubernetes_cluster_node_pool" "additional_node_pool" {
  for_each = var.additional_node_pools

  name                  = each.key
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks.id
  node_count            = each.value.node_count
  vm_size               = each.value.vm_size
  availability_zones    = each.value.availability_zones
  vnet_subnet_id        = var.aks_subnet_id
  os_disk_size_gb       = each.value.os_disk_size_gb

  enable_auto_scaling = each.value.enable_auto_scaling
  min_count          = each.value.min_count
  max_count          = each.value.max_count

  node_labels = each.value.node_labels
  node_taints = each.value.node_taints

  priority = each.value.priority  # "Regular" or "Spot"
  eviction_policy = each.value.priority == "Spot" ? "Delete" : null
  spot_max_price  = each.value.priority == "Spot" ? each.value.spot_max_price : null

  tags = merge(
    var.common_tags,
    {
      Name = each.key
    }
  )
}
