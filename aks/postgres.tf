### Azure Database for PostgreSQL Flexible Server

# Delegated Subnet for PostgreSQL (Flexible Server requires a dedicated delegated subnet)
resource "azurerm_subnet" "postgres_subnet" {
  name                 = "${var.res_prefix}-postgres-subnet"
  resource_group_name  = azurerm_resource_group.resource_group.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.postgres_subnet_address]

  delegation {
    name = "postgresql-delegation"

    service_delegation {
      name = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
      ]
    }
  }
}

# Private DNS Zone for PostgreSQL
resource "azurerm_private_dns_zone" "postgres_zone" {
  name                = "${var.postgres_hostname}.private.postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.resource_group.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "postgres_vnet_link" {
  name                  = "${var.postgres_hostname}-vnet-link"
  resource_group_name   = azurerm_resource_group.resource_group.name
  private_dns_zone_name = azurerm_private_dns_zone.postgres_zone.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
}

# PostgreSQL Flexible Server
resource "azurerm_postgresql_flexible_server" "postgres" {
  name                          = var.postgres_hostname
  resource_group_name           = azurerm_resource_group.resource_group.name
  location                      = azurerm_resource_group.resource_group.location
  version                       = var.postgres_version
  delegated_subnet_id           = azurerm_subnet.postgres_subnet.id
  private_dns_zone_id           = azurerm_private_dns_zone.postgres_zone.id
  public_network_access_enabled = false
  administrator_login           = var.postgres_username
  administrator_password        = var.postgres_password
  storage_mb                    = var.postgres_storage_size * 1024
  sku_name                      = var.postgres_sku
  backup_retention_days         = 7
  geo_redundant_backup_enabled  = false
  auto_grow_enabled             = true
  zone                          = "1"

  depends_on = [azurerm_private_dns_zone_virtual_network_link.postgres_vnet_link]
}

# PostgreSQL Server Configuration
resource "azurerm_postgresql_flexible_server_configuration" "extensions" {
  name      = "azure.extensions"
  server_id = azurerm_postgresql_flexible_server.postgres.id
  value     = "btree_gin"
}
