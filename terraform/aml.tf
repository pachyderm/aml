resource "azurerm_application_insights" "example" {
  count = var.existing_workspace_name == "" ? 1 : 0
  name                = "insights-${random_id.deployment.hex}"
  location            = local.resource_group_location
  resource_group_name = local.resource_group_name
  application_type    = "web"
}

resource "azurerm_key_vault" "example" {
  count = var.existing_workspace_name == "" ? 1 : 0
  name                     = "vault-${random_id.deployment.hex}"
  location                 = local.resource_group_location
  resource_group_name      = local.resource_group_name
  tenant_id                = data.azurerm_client_config.current.tenant_id
  sku_name                 = "premium"
  purge_protection_enabled = true
}

resource "azurerm_storage_account" "example" {
  count = var.existing_workspace_name == "" ? 1 : 0
  name                     = "storageaml-${random_id.deployment.hex}"
  location                 = local.resource_group_location
  resource_group_name      = local.resource_group_name
  account_tier             = "Standard"
  account_replication_type = "GRS"
}

resource "azurerm_machine_learning_workspace" "example" {
  count = var.existing_workspace_name == "" ? 1 : 0
  name                    = "workspace-${random_id.deployment.hex}"
  location                = local.resource_group_location
  resource_group_name     = local.resource_group_name
  application_insights_id = azurerm_application_insights.example[0].id
  key_vault_id            = azurerm_key_vault.example[0].id
  storage_account_id      = azurerm_storage_account.example[0].id

  identity {
    type = "SystemAssigned"
  }
}

data "azurerm_machine_learning_workspace" "existing" {
  count = var.existing_workspace_name == "" ? 0 : 1
  name                = var.existing_workspace_name
  resource_group_name = local.resource_group_name
}

locals {
  machine_learning_workspace_id = var.existing_workspace_name == "" ? azurerm_machine_learning_workspace.example[0].id : data.azurerm_machine_learning_workspace.existing[0].id
  machine_learning_workspace_name = var.existing_workspace_name == "" ? azurerm_machine_learning_workspace.example[0].name : var.existing_workspace_name
}
