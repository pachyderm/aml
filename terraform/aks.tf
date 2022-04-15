resource "azurerm_kubernetes_cluster" "example" {
  count               = var.skip_pachyderm_deploy == "" ? 1 : 0
  name                = "pachyderm-${random_id.deployment.hex}"
  location            = local.resource_group_location
  resource_group_name = local.resource_group_name
  dns_prefix          = "pachydermaks"

  default_node_pool {
    name       = "default"
    node_count = 3
    vm_size    = "Standard_D2s_v3"
    # vnet_subnet_id = azurerm_subnet.internal.id
  }

  identity {
    type = "SystemAssigned"
  }

  tags = {
    Environment = "Production"
  }
}

output "client_certificate" {
  sensitive = true
  value = var.skip_pachyderm_deploy == "" ? azurerm_kubernetes_cluster.example[0].kube_config.0.client_certificate : ""
}

output "kube_config" {
  sensitive = true
  value     = var.skip_pachyderm_deploy == "" ? azurerm_kubernetes_cluster.example[0].kube_config_raw : ""
}
output "kube_context" {
  sensitive = false
  value     = var.skip_pachyderm_deploy == "" ? azurerm_kubernetes_cluster.example[0].name : ""
}
