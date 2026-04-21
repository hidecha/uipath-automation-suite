output "bastion_public_ip_address" {
  value = azurerm_windows_virtual_machine.bastion_vm.public_ip_address
}

output "client_private_ip_address" {
  value = azurerm_linux_virtual_machine.client_vm.private_ip_address
}

output "sqlserver_hostname" {
  value = azurerm_mssql_server.sql_server.fully_qualified_domain_name
}

output "postgres_hostname" {
  value = azurerm_postgresql_flexible_server.postgres.fqdn
}

output "postgres_port" {
  value = 5432
}

output "AKS_public_ip_address" {
  value = var.enable_public_access ? data.azurerm_public_ip.aks_public_ip[0].ip_address : null
}

