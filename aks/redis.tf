### Redis Cache

resource "azurerm_redis_cache" "redis" {
  name                          = var.redis_hostname
  location                      = azurerm_resource_group.resource_group.location
  resource_group_name           = azurerm_resource_group.resource_group.name
  capacity                      = 2
  family                        = "C"
  sku_name                      = "Standard"
  non_ssl_port_enabled          = false
  public_network_access_enabled = false

  redis_configuration {
  }
}

resource "azurerm_private_endpoint" "redis_endpoint" {
  name                = "${var.redis_hostname}-endpoint"
  resource_group_name = azurerm_resource_group.resource_group.name
  location            = azurerm_resource_group.resource_group.location
  subnet_id           = azurerm_subnet.subnet.id
  depends_on          = [azurerm_redis_cache.redis]

  private_service_connection {
    name                           = "${var.redis_hostname}-private-conn"
    private_connection_resource_id = azurerm_redis_cache.redis.id
    subresource_names              = ["redisCache"]
    is_manual_connection           = false
  }
}

data "azurerm_private_endpoint_connection" "redis_conn" {
  name                = azurerm_private_endpoint.redis_endpoint.name
  resource_group_name = azurerm_resource_group.resource_group.name
}

resource "azurerm_private_dns_zone" "redis_zone" {
  name                = "privatelink.redis.cache.windows.net"
  resource_group_name = azurerm_resource_group.resource_group.name
  depends_on          = [azurerm_private_endpoint.redis_endpoint]
}

resource "azurerm_private_dns_zone_virtual_network_link" "redis_vnet_link" {
  name                  = "${var.redis_hostname}-vnet-link"
  resource_group_name   = azurerm_resource_group.resource_group.name
  private_dns_zone_name = azurerm_private_dns_zone.redis_zone.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
}

resource "azurerm_private_dns_a_record" "redis_dns_record" {
  name                = azurerm_redis_cache.redis.name
  zone_name           = azurerm_private_dns_zone.redis_zone.name
  resource_group_name = azurerm_resource_group.resource_group.name
  ttl                 = 3600
  records             = [data.azurerm_private_endpoint_connection.redis_conn.private_service_connection[0].private_ip_address]
}
