# Automation Suite on AKS
provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "resource_group" {
  name     = var.rg_name
  location = var.location
  tags     = var.tags
}
