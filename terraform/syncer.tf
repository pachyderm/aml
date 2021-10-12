resource "azurerm_public_ip" "pip" {
  name                = "publicip-${random_id.deployment.hex}"
  resource_group_name = local.resource_group_name
  location            = local.resource_group_location
  allocation_method   = "Dynamic"
}

resource "azurerm_network_interface" "main" {
  name                = "nic1-${random_id.deployment.hex}"
  resource_group_name = local.resource_group_name
  location            = local.resource_group_location

  ip_configuration {
    name                          = "primary"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip.id
  }
}

resource "azurerm_network_interface" "internal" {
  name                = "nic2-${random_id.deployment.hex}"
  resource_group_name = local.resource_group_name
  location            = local.resource_group_location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_security_group" "ssh" {
  name                = "ssh-${random_id.deployment.hex}"
  location            = local.resource_group_location
  resource_group_name = local.resource_group_name
  security_rule {
    access                     = "Allow"
    direction                  = "Inbound"
    name                       = "tls"
    priority                   = 100
    protocol                   = "Tcp"
    source_port_range          = "*"
    source_address_prefix      = "*"
    destination_port_range     = "22"
    destination_address_prefix = azurerm_network_interface.main.private_ip_address
  }
}

resource "azurerm_network_interface_security_group_association" "main" {
  network_interface_id      = azurerm_network_interface.internal.id
  network_security_group_id = azurerm_network_security_group.ssh.id
}

resource "azurerm_linux_virtual_machine" "syncer" {
  name                            = "syncer-${random_id.deployment.hex}"
  resource_group_name             = local.resource_group_name
  location                        = local.resource_group_location
  size                            = "Standard_D2s_v3"
  disable_password_authentication = true
  admin_username                  = "pachyderm"
  network_interface_ids = [
    azurerm_network_interface.main.id,
    azurerm_network_interface.internal.id,
  ]

  // So that we can give it permission onto AML (see main.tf)
  identity {
    type = "SystemAssigned"
  }

  admin_ssh_key {
    username   = "pachyderm"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  source_image_reference {
    publisher = "pachyderminc1585170006545"
    offer     = "pachyderm_aml_enablement"
    sku       = "base-aml-pachyderm-plan"
    version   = "0.0.4"
  }

  plan {
    name      = "base-aml-pachyderm-plan"
    product   = "pachyderm_aml_enablement"
    publisher = "pachyderminc1585170006545"
  }

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }
}

output "instance_ip" {
  value = azurerm_linux_virtual_machine.syncer.public_ip_address
}
