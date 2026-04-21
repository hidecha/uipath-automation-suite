### AKS Backup

data "azurerm_client_config" "current" {}

### Backup Vault

resource "azurerm_data_protection_backup_vault" "backup_vault" {
  name                = "${var.res_prefix}-backup-vault"
  resource_group_name = azurerm_resource_group.resource_group.name
  location            = azurerm_resource_group.resource_group.location
  datastore_type      = "VaultStore"
  redundancy          = "LocallyRedundant"

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

### Storage Account for Backup

resource "azurerm_storage_account" "backup_storage" {
  name                     = var.backup_storage_account
  resource_group_name      = azurerm_resource_group.resource_group.name
  location                 = azurerm_resource_group.resource_group.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = var.tags
}

resource "azurerm_storage_container" "backup_container" {
  name               = "aks-backup"
  storage_account_id = azurerm_storage_account.backup_storage.id
}

### AKS Backup Extension

resource "azurerm_kubernetes_cluster_extension" "backup_extension" {
  name           = "azure-aks-backup"
  cluster_id     = azurerm_kubernetes_cluster.aks_cluster.id
  extension_type = "Microsoft.DataProtection.Kubernetes"
  release_train  = "stable"

  configuration_settings = {
    "configuration.backupStorageLocation.bucket"                = azurerm_storage_container.backup_container.name
    "configuration.backupStorageLocation.config.resourceGroup"  = azurerm_resource_group.resource_group.name
    "configuration.backupStorageLocation.config.storageAccount" = azurerm_storage_account.backup_storage.name
    "configuration.backupStorageLocation.config.subscriptionId" = data.azurerm_client_config.current.subscription_id
    "credentials.tenantId"                                      = data.azurerm_client_config.current.tenant_id
  }
}

### Role Assignments - Backup Vault Identity

resource "azurerm_role_assignment" "backup_vault_reader_aks" {
  scope                = azurerm_kubernetes_cluster.aks_cluster.id
  role_definition_name = "Reader"
  principal_id         = azurerm_data_protection_backup_vault.backup_vault.identity[0].principal_id
}

resource "azurerm_role_assignment" "backup_vault_reader_rg" {
  scope                = azurerm_resource_group.resource_group.id
  role_definition_name = "Reader"
  principal_id         = azurerm_data_protection_backup_vault.backup_vault.identity[0].principal_id
}

resource "azurerm_role_assignment" "backup_vault_snapshot_contributor" {
  scope                = azurerm_resource_group.resource_group.id
  role_definition_name = "Disk Snapshot Contributor"
  principal_id         = azurerm_data_protection_backup_vault.backup_vault.identity[0].principal_id
}

resource "azurerm_role_assignment" "backup_vault_data_operator" {
  scope                = azurerm_resource_group.resource_group.id
  role_definition_name = "Data Operator for Managed Disks"
  principal_id         = azurerm_data_protection_backup_vault.backup_vault.identity[0].principal_id
}

### Role Assignments - Backup Extension Identity

resource "azurerm_role_assignment" "backup_extension_storage_contributor" {
  scope                = azurerm_storage_account.backup_storage.id
  role_definition_name = "Storage Account Contributor"
  principal_id         = azurerm_kubernetes_cluster_extension.backup_extension.aks_assigned_identity[0].principal_id
}

### Role Assignments - AKS Cluster Identity

resource "azurerm_role_assignment" "aks_snapshot_contributor" {
  scope                = azurerm_resource_group.resource_group.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_kubernetes_cluster.aks_cluster.identity[0].principal_id
}

### Trusted Access Role Binding

resource "azurerm_kubernetes_cluster_trusted_access_role_binding" "backup_trusted_access" {
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks_cluster.id
  name                  = "${var.res_prefix}-bkp-ta"
  roles                 = ["Microsoft.DataProtection/backupVaults/backup-operator"]
  source_resource_id    = azurerm_data_protection_backup_vault.backup_vault.id
}

### Backup Policy

resource "azurerm_data_protection_backup_policy_kubernetes_cluster" "backup_policy" {
  name                = "${var.res_prefix}-aks-backup-policy"
  resource_group_name = azurerm_resource_group.resource_group.name
  vault_name          = azurerm_data_protection_backup_vault.backup_vault.name

  backup_repeating_time_intervals = ["R/2024-01-01T17:00:00+00:00/P1D"]

  default_retention_rule {
    life_cycle {
      duration        = "P7D"
      data_store_type = "OperationalStore"
    }
  }
}

### Backup Instance

resource "azurerm_data_protection_backup_instance_kubernetes_cluster" "backup_instance" {
  name                         = "${var.res_prefix}-aks-backup-instance"
  location                     = azurerm_resource_group.resource_group.location
  vault_id                     = azurerm_data_protection_backup_vault.backup_vault.id
  kubernetes_cluster_id        = azurerm_kubernetes_cluster.aks_cluster.id
  snapshot_resource_group_name = azurerm_resource_group.resource_group.name
  backup_policy_id             = azurerm_data_protection_backup_policy_kubernetes_cluster.backup_policy.id

  backup_datasource_parameters {
    excluded_namespaces              = []
    excluded_resource_types          = []
    cluster_scoped_resources_enabled = true
    included_namespaces              = []
    included_resource_types          = []
    label_selectors                  = []
    volume_snapshot_enabled          = true
  }

  depends_on = [
    azurerm_role_assignment.backup_vault_reader_aks,
    azurerm_role_assignment.backup_vault_reader_rg,
    azurerm_role_assignment.backup_extension_storage_contributor,
    azurerm_role_assignment.backup_vault_snapshot_contributor,
    azurerm_role_assignment.backup_vault_data_operator,
    azurerm_role_assignment.aks_snapshot_contributor,
    azurerm_kubernetes_cluster_trusted_access_role_binding.backup_trusted_access,
  ]
}
