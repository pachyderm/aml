// Storage for pachyderm cluster

resource "azurerm_storage_account" "pachyderm" {
  name                     = "pachyderm-${random_id.deployment.hex}"
  resource_group_name      = local.resource_group_name
  location                 = local.resource_group_location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "pachyderm" {
  name                  = "pachyderm-${random_id.deployment.hex}"
  storage_account_name  = azurerm_storage_account.pachyderm.name
  container_access_type = "private"
}
