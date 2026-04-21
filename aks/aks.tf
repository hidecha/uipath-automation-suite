### AKS Cluster

resource "azurerm_kubernetes_cluster" "aks_cluster" {
  name                = "${var.res_prefix}-cluster"
  resource_group_name = azurerm_resource_group.resource_group.name
  location            = azurerm_resource_group.resource_group.location

  dns_prefix              = "${var.res_prefix}-dns"
  kubernetes_version      = var.kubernetes_version
  sku_tier                = "Free"
  private_cluster_enabled = !var.enable_public_access

  network_profile {
    network_mode      = "transparent"
    network_plugin    = "azure"
    network_policy    = "calico"
    service_cidr      = var.aks_subnet_address
    dns_service_ip    = var.aks_dns_ip
    load_balancer_sku = "standard"
  }

  default_node_pool {
    name                        = "pool0"
    vm_size                     = var.aks_node_size
    vnet_subnet_id              = azurerm_subnet.subnet.id
    os_disk_size_gb             = 512
    auto_scaling_enabled        = false
    node_count                  = var.number_of_cpu_nodes
    max_pods                    = 100
    temporary_name_for_rotation = "pooltmp"
  }

  identity {
    type = "SystemAssigned"
  }

  tags       = var.tags
  depends_on = [azurerm_subnet.subnet]
}

### Role Assignment - Grant AKS Managed Identity "Network Contributor" on VNet
### Required for LoadBalancer creation on the subnet

resource "azurerm_role_assignment" "aks_network_contributor" {
  scope                = azurerm_virtual_network.vnet.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_kubernetes_cluster.aks_cluster.identity[0].principal_id
}

### Serverless Robot Node Pool

resource "azurerm_kubernetes_cluster_node_pool" "asrobot_pool" {
  count                 = var.number_of_asrobot_nodes > 0 ? 1 : 0
  name                  = "asrobot"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks_cluster.id
  vm_size               = var.aks_node_size
  vnet_subnet_id        = azurerm_subnet.subnet.id
  os_disk_size_gb       = 512
  node_count            = var.number_of_asrobot_nodes
  max_pods              = 100

  node_taints = ["serverless.robot=present:NoSchedule"]

  node_labels = {
    "serverless.robot"  = "true"
    "serverless.daemon" = "true"
  }
}

data "azurerm_public_ip" "aks_public_ip" {
  count               = var.enable_public_access ? 1 : 0
  name                = split("/", tolist(azurerm_kubernetes_cluster.aks_cluster.network_profile[0].load_balancer_profile[0].effective_outbound_ips)[0])[8]
  resource_group_name = split("/", tolist(azurerm_kubernetes_cluster.aks_cluster.network_profile[0].load_balancer_profile[0].effective_outbound_ips)[0])[4]
}

### Private DNS Zone for Automation Suite

resource "azurerm_private_dns_zone" "as_zone" {
  name                = var.aks_fqdn
  resource_group_name = azurerm_resource_group.resource_group.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "as_vnet_link" {
  name                  = "${var.res_prefix}-link"
  resource_group_name   = azurerm_resource_group.resource_group.name
  private_dns_zone_name = azurerm_private_dns_zone.as_zone.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
}

resource "azurerm_private_dns_cname_record" "as_dns_cname_record" {
  for_each = toset(["alm", "monitoring", "objectstore", "registry", "insights", "apps"])

  name                = each.key
  zone_name           = azurerm_private_dns_zone.as_zone.name
  resource_group_name = azurerm_resource_group.resource_group.name
  ttl                 = 3600
  record              = var.aks_fqdn
}
