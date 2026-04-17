### Azure SQL Server

resource "azurerm_mssql_server" "sql_server" {
  name                          = var.sql_hostname
  resource_group_name           = azurerm_resource_group.resource_group.name
  location                      = azurerm_resource_group.resource_group.location
  version                       = "12.0"
  administrator_login           = var.sql_username
  administrator_login_password  = var.sql_password
  public_network_access_enabled = false
}

resource "azurerm_private_endpoint" "sql_server_endpoint" {
  name                = "${var.sql_hostname}-endpoint"
  resource_group_name = azurerm_resource_group.resource_group.name
  location            = azurerm_resource_group.resource_group.location
  subnet_id           = azurerm_subnet.subnet.id
  depends_on          = [azurerm_mssql_server.sql_server]

  private_service_connection {
    name                           = "${var.sql_hostname}-private-conn"
    private_connection_resource_id = azurerm_mssql_server.sql_server.id
    subresource_names              = ["sqlServer"]
    is_manual_connection           = false
  }
}

data "azurerm_private_endpoint_connection" "sql_server_conn" {
  name                = azurerm_private_endpoint.sql_server_endpoint.name
  resource_group_name = azurerm_resource_group.resource_group.name
}

resource "azurerm_private_dns_zone" "sql_server_zone" {
  name                = "privatelink.database.windows.net"
  resource_group_name = azurerm_resource_group.resource_group.name
  depends_on          = [azurerm_private_endpoint.sql_server_endpoint]
}

resource "azurerm_private_dns_zone_virtual_network_link" "sql_server_vnet_link" {
  name                  = "${var.sql_hostname}-vnet-link"
  resource_group_name   = azurerm_resource_group.resource_group.name
  private_dns_zone_name = azurerm_private_dns_zone.sql_server_zone.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
}

resource "azurerm_private_dns_a_record" "sql_server_dns_record" {
  name                = azurerm_mssql_server.sql_server.name
  zone_name           = azurerm_private_dns_zone.sql_server_zone.name
  resource_group_name = azurerm_resource_group.resource_group.name
  ttl                 = 3600
  records             = [data.azurerm_private_endpoint_connection.sql_server_conn.private_service_connection[0].private_ip_address]
}
