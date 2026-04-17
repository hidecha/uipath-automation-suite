### Storage Account (Object Store)

resource "azurerm_storage_account" "storage_account" {
  name                          = var.storage_account
  location                      = azurerm_resource_group.resource_group.location
  resource_group_name           = azurerm_resource_group.resource_group.name
  account_tier                  = "Standard"
  account_replication_type      = "LRS"
  public_network_access_enabled = false
}

### Storage Queues

resource "azurerm_storage_queue" "queues" {
  for_each = toset([
    "gallupx-core",
    "gallupx-cron-tasks",
    "gallupx-debug-engine-tasks",
    "gallupx-engine-tasks",
    "gallupx-event-tasks",
    "gallupx-fps-engine-tasks",
    "gallupx-notification-tasks",
    "gallupx-tick-tasks",
    "gallupx-webhook-engine-tasks",
  ])

  name               = each.key
  storage_account_id = azurerm_storage_account.storage_account.id
}

### Blob Containers

resource "azurerm_storage_container" "containers" {
  for_each = toset([
    "gallupx-poller-data",
    "gallupx-job-engine-state",
    "gallupx-notification-objects",
    "gallupx-webhook",
    "gallupx-execution-trace",
  ])

  name               = each.key
  storage_account_id = azurerm_storage_account.storage_account.id
}

resource "azurerm_private_endpoint" "storage_endpoint" {
  name                = "${var.storage_account}-endpoint"
  resource_group_name = azurerm_resource_group.resource_group.name
  location            = azurerm_resource_group.resource_group.location
  subnet_id           = azurerm_subnet.subnet.id
  depends_on          = [azurerm_storage_account.storage_account]

  private_service_connection {
    name                           = "${var.storage_account}-private-conn"
    private_connection_resource_id = azurerm_storage_account.storage_account.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }
}

data "azurerm_private_endpoint_connection" "storage_conn" {
  name                = azurerm_private_endpoint.storage_endpoint.name
  resource_group_name = azurerm_resource_group.resource_group.name
}

resource "azurerm_private_dns_zone" "storage_zone" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = azurerm_resource_group.resource_group.name
  depends_on          = [azurerm_private_endpoint.storage_endpoint]
}

resource "azurerm_private_dns_zone_virtual_network_link" "storage_vnet_link" {
  name                  = "${var.storage_account}-vnet-link"
  resource_group_name   = azurerm_resource_group.resource_group.name
  private_dns_zone_name = azurerm_private_dns_zone.storage_zone.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
}

resource "azurerm_private_dns_a_record" "storage_account_dns_record" {
  name                = azurerm_storage_account.storage_account.name
  zone_name           = azurerm_private_dns_zone.storage_zone.name
  resource_group_name = azurerm_resource_group.resource_group.name
  ttl                 = 3600
  records             = [data.azurerm_private_endpoint_connection.storage_conn.private_service_connection[0].private_ip_address]
}

### Storage Queue Private Endpoint

resource "azurerm_private_endpoint" "storage_queue_endpoint" {
  name                = "${var.storage_account}-queue-endpoint"
  resource_group_name = azurerm_resource_group.resource_group.name
  location            = azurerm_resource_group.resource_group.location
  subnet_id           = azurerm_subnet.subnet.id
  depends_on          = [azurerm_storage_account.storage_account]

  private_service_connection {
    name                           = "${var.storage_account}-queue-private-conn"
    private_connection_resource_id = azurerm_storage_account.storage_account.id
    subresource_names              = ["queue"]
    is_manual_connection           = false
  }
}

data "azurerm_private_endpoint_connection" "storage_queue_conn" {
  name                = azurerm_private_endpoint.storage_queue_endpoint.name
  resource_group_name = azurerm_resource_group.resource_group.name
}

resource "azurerm_private_dns_zone" "storage_queue_zone" {
  name                = "privatelink.queue.core.windows.net"
  resource_group_name = azurerm_resource_group.resource_group.name
  depends_on          = [azurerm_private_endpoint.storage_queue_endpoint]
}

resource "azurerm_private_dns_zone_virtual_network_link" "storage_queue_vnet_link" {
  name                  = "${var.storage_account}-queue-vnet-link"
  resource_group_name   = azurerm_resource_group.resource_group.name
  private_dns_zone_name = azurerm_private_dns_zone.storage_queue_zone.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
}

resource "azurerm_private_dns_a_record" "storage_queue_dns_record" {
  name                = azurerm_storage_account.storage_account.name
  zone_name           = azurerm_private_dns_zone.storage_queue_zone.name
  resource_group_name = azurerm_resource_group.resource_group.name
  ttl                 = 3600
  records             = [data.azurerm_private_endpoint_connection.storage_queue_conn.private_service_connection[0].private_ip_address]
}
