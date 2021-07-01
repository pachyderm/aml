// Storage for pachyderm cluster

resource "azurerm_storage_account" "pachyderm" {
  name                     = "pachyderm${random_id.deployment.hex}"
  resource_group_name      = azurerm_resource_group.main[0].name
  location                 = azurerm_resource_group.main[0].location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "pachyderm" {
  name                  = "pachyderm"
  storage_account_name  = azurerm_storage_account.pachyderm.name
  container_access_type = "private"
}

/*
output "storage_access_key" {
  value = azurerm_storage_account.pachyderm.primary_access_key
}
output "storage_account_name" {
  value = azurerm_storage_account.pachyderm.name
}
*/