# We strongly recommend using the required_providers block to set the
# Azure Provider source and version being used
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=2.46.0"
    }
  }
}
resource "random_id" "deployment" {
  byte_length = 4
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {}
}

data "azurerm_client_config" "current" {}

# Create or lookup a resource group

resource "azurerm_resource_group" "main" {
  count = var.existing_resource_group_name == "" ? 1 : 0
  name     = "resources-${random_id.deployment.hex}"
  location = var.location
}

data "azurerm_resource_group" "existing" {
  count = var.existing_resource_group_name == "" ? 0 : 1
  name = var.existing_resource_group_name
}

locals {
  resource_group_name = var.existing_resource_group_name == "" ? azurerm_resource_group.main[0].name : data.azurerm_resource_group.existing[0].name
  resource_group_location = var.existing_resource_group_name == "" ? azurerm_resource_group.main[0].location : data.azurerm_resource_group.existing[0].location
}


# Create a virtual network within the resource group

resource "azurerm_virtual_network" "main" {
  name                = "network-${random_id.deployment.hex}"
  address_space       = ["10.0.0.0/16"]
  location            = local.resource_group_location
  resource_group_name = local.resource_group_name
}

# subnet for the vm
resource "azurerm_subnet" "internal" {
  name                 = "internal-${random_id.deployment.hex}"
  resource_group_name  = local.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.2.0/24"]
}

# subnet for the aks cluster and aml to share
#resource "azurerm_subnet" "internal2" {
#  name                 = "internal2-${random_id.deployment.hex}"
#  resource_group_name  = local.resource_group_name
#  virtual_network_name = azurerm_virtual_network.main.name
#  address_prefixes     = ["10.0.2.0/24"]
#}

# Role assignment from VM -> AML

resource "azurerm_role_assignment" "example" {
  scope                = local.machine_learning_workspace_id
  role_definition_name = "Contributor"
  principal_id         = azurerm_linux_virtual_machine.syncer.identity[0].principal_id
}

resource "local_file" "env" {
  filename = "${path.module}/../scripts/env.sh"
  content = <<EOT

# azureml instance
export AZURE_SUBSCRIPTION_ID="${data.azurerm_client_config.current.subscription_id}"
export AZURE_RESOURCE_GROUP="${local.resource_group_name}"
export AZURE_ML_WORKSPACE_NAME="${local.machine_learning_workspace_id}"

# storage for pachyderm
export AZURE_STORAGE_CONTAINER="${azurerm_storage_container.pachyderm.name}"
export AZURE_STORAGE_ACCOUNT_NAME="${azurerm_storage_account.pachyderm.name}"
export AZURE_STORAGE_ACCOUNT_KEY="${azurerm_storage_account.pachyderm.primary_access_key}"

export PACHD_SERVICE_HOST="localhost"
export PACHD_SERVICE_PORT="30650"

EOT
}

output "azure_subscription_id" {
  value = data.azurerm_client_config.current.subscription_id
}

output "azure_resource_group" {
  value = local.resource_group_name
}

output "azure_ml_workspace_name" {
  value = local.machine_learning_workspace_name
}
