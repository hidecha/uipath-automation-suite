### Bastion VM (Windows)

resource "azurerm_public_ip" "bastion_pip" {
  name                = "${var.res_prefix}-bastion-pip"
  location            = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name
  allocation_method   = "Static"
}

resource "azurerm_network_interface" "bastion_nic" {
  name                = "${var.res_prefix}-bastion-nic"
  location            = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name

  ip_configuration {
    name                          = "ipconfig"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.bastion_pip.id
  }
}

resource "azurerm_network_interface_security_group_association" "bastion_sg_nic" {
  network_interface_id      = azurerm_network_interface.bastion_nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_windows_virtual_machine" "bastion_vm" {
  name                  = "${var.res_prefix}-bastion"
  resource_group_name   = azurerm_resource_group.resource_group.name
  location              = azurerm_resource_group.resource_group.location
  size                  = "Standard_D2as_v4"
  computer_name         = "bastion"
  admin_username        = var.vm_username
  admin_password        = var.vm_password
  network_interface_ids = [azurerm_network_interface.bastion_nic.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-g2"
    version   = "latest"
  }
}

### Client VM (Linux / RHEL)

resource "azurerm_network_interface" "client_nic" {
  name                           = "${var.res_prefix}-client-nic"
  location                       = azurerm_resource_group.resource_group.location
  resource_group_name            = azurerm_resource_group.resource_group.name
  accelerated_networking_enabled = true

  ip_configuration {
    name                          = "client_nic_configuration"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_interface_security_group_association" "client_sg_nic" {
  network_interface_id      = azurerm_network_interface.client_nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_linux_virtual_machine" "client_vm" {
  name                  = "${var.res_prefix}-${var.client_hostname}"
  location              = azurerm_resource_group.resource_group.location
  resource_group_name   = azurerm_resource_group.resource_group.name
  network_interface_ids = [azurerm_network_interface.client_nic.id]
  size                  = "Standard_F2s_v2"

  os_disk {
    name                 = "${var.res_prefix}-${var.client_hostname}_OsDisk"
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  source_image_reference {
    publisher = "RedHat"
    offer     = "RHEL"
    sku       = "97-gen2"
    version   = "latest"
  }

  computer_name                   = var.client_hostname
  admin_username                  = var.vm_username
  admin_password                  = var.vm_password
  disable_password_authentication = false
}
