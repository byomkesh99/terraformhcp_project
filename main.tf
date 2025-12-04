#########################################################
# Provider
#########################################################
provider "azurerm" {
  features {}
}

#########################################################
# Resource Group
#########################################################
resource "azurerm_resource_group" "rg" {
  name     = "rg-single-vm"
#  location = "westeurope"
  location = "francecentral"
}

#########################################################
# Virtual Network + Subnet
#########################################################
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-single"
  address_space       = ["10.10.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "subnet-main"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.10.1.0/24"]
}

#########################################################
# Public IP (Dynamic)
#########################################################
resource "azurerm_public_ip" "public_ip" {
  name                = "vm-public-ip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

#########################################################
# Network Security Group (Allow SSH)
#########################################################
resource "azurerm_network_security_group" "nsg" {
  name                = "nsg-ssh"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "Allow-SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

#########################################################
# Network Interface
#########################################################
resource "azurerm_network_interface" "nic" {
  name                = "nic-single"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public_ip.id
  }
}

resource "azurerm_network_interface_security_group_association" "nic_nsg_assoc" {
  network_interface_id      = azurerm_network_interface.nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

#########################################################
# Virtual Machine (username + password + auto-delete disk)
#########################################################
resource "azurerm_linux_virtual_machine" "vm" {
  name                = "single-ubuntu-vm"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  size                = "Standard_B1s"

## Login With Username and Password
  admin_username = "azureuser"
  admin_password = "StrongPassword@123!"
  disable_password_authentication = false

## Login with SSH key
#  admin_ssh_key {
#    username   = "azureuser"
#    public_key = file("~/.ssh/keycloud.pub") # Use your laptop SSH public key
#  }

  network_interface_ids = [
    azurerm_network_interface.nic.id
  ]

  # 🔥 IMPORTANT: Delete disk(s) when VM is destroyed
  #delete_os_disk_on_termination    = true
  #delete_data_disks_on_termination = true

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts"
    version   = "latest"
  }
}

#########################################################
# Output: Public IP
#########################################################
output "public_ip" {
  value = azurerm_public_ip.public_ip.ip_address
}
