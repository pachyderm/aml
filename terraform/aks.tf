resource "azurerm_kubernetes_cluster" "example" {
  name                = "pachyderm-${random_id.deployment.hex}"
  location            = local.resource_group_location
  resource_group_name = local.resource_group_name
  dns_prefix          = "pachydermaks"

  default_node_pool {
    name       = "default"
    node_count = 3
    vm_size    = "Standard_D2_v2"
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
  value = azurerm_kubernetes_cluster.example.kube_config.0.client_certificate
}

output "kube_config" {
  sensitive = true
  value     = azurerm_kubernetes_cluster.example.kube_config_raw
}
