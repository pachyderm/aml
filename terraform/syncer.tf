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

data "azurerm_resource_group" "image" {
  name = var.syncer_image_resource_group
}

data "azurerm_image" "image" {
  name                = var.syncer_image_name
  resource_group_name = data.azurerm_resource_group.image.name
}

resource "azurerm_linux_virtual_machine" "syncer" {
  name                            = "syncer-${random_id.deployment.hex}"
  resource_group_name             = local.resource_group_name
  location                        = local.resource_group_location
  size                            = "Standard_D2s_v3"
  disable_password_authentication = true
  admin_username                  = "terraform"
  network_interface_ids = [
    azurerm_network_interface.main.id,
    azurerm_network_interface.internal.id,
  ]

  // So that we can give it permission onto AML (see main.tf)
  identity {
    type = "SystemAssigned"
  }

  admin_ssh_key {
    username   = "terraform"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  source_image_id = "/subscriptions/04701c5f-d635-4103-a3a9-0d74aa3ddc51/resourceGroups/packer/providers/Microsoft.Compute/galleries/gallery/images/aml_pachyderm/versions/0.0.1"

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }
}

output "instance_ip" {
  value = azurerm_linux_virtual_machine.syncer.public_ip_address
}
