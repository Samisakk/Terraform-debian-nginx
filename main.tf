# Configure the Azure provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 2.65"
    }
  }

  required_version = ">= 1.1.0"
}

provider "azurerm" {
  features {}
 subscription_id = var.subscription_id
 tenant_id = var.tenant_id
}

#create RG
resource "azurerm_resource_group" "rg" {
  name     = "Samiterrarg"
  location = "westeurope"
  tags ={
    enviroment = "terraform getting started"
    Team = " DevOps"
  }
}
resource "azurerm_subnet" "subnet" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}
resource "azurerm_network_interface" "nic" {
  name                = "samiterranic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "ipconfiguration"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id           = azurerm_public_ip.publicip.id
        
  }
}

resource "azurerm_network_security_group" "nsg" {
  name                = "acceptanceTestSecurityGroup1"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "samiNSG"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    environment = "Production"
  }
}
#create public ip
resource "azurerm_public_ip" "publicip" {
  name                = "samiterrapublicip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}
resource "azurerm_public_ip_prefix" "pubipprefix" {
  name                = "nat-gateway-publicipprefix"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  prefix_length       = 30
}
resource "azurerm_network_interface_security_group_association" "nicassociate" {
  network_interface_id      = azurerm_network_interface.nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# Create a virtual network
resource "azurerm_virtual_network" "vnet" {
    name                = "samiterravnet"
    address_space       = ["10.0.0.0/16"]
    location            = "westeurope"
    resource_group_name = azurerm_resource_group.rg.name
}
#create storage account
resource "azurerm_storage_account" "storageaccount" {
  name                     = "samiterrastorageacco"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "GRS"

  tags = {
    environment = "staging"
  }
}
#create storage container
resource "azurerm_storage_container" "storagecont" {
  name                  = "saminterracontainer"
  storage_account_name  = azurerm_storage_account.storageaccount.name
  container_access_type = "private"
}

resource "azurerm_virtual_machine" "vm" {
  name                  = "samiterravm"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.nic.id]
  vm_size               = "Standard_B2s"
  
  storage_image_reference {
    publisher = "Debian"
    offer     = "debian-11"
    sku       = "11-gen2"
    version   = "latest"
  }

  storage_os_disk {
    name          = "saminlinuxdisk"
    caching       = "ReadWrite"
    create_option = "FromImage"
  }

  os_profile {
    computer_name  = "samilinuxvm"
    admin_username = "sami"
    admin_password = var.vmsalasana
    
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }
}
resource "azurerm_virtual_machine_extension" "vme" {

  virtual_machine_id         = azurerm_virtual_machine.vm.id
  name                       = "vme"
  publisher                  = "Microsoft.Azure.Extensions"
  type                       = "CustomScript"
  type_handler_version       = "2.0"
  auto_upgrade_minor_version = true
  settings = <<SETTINGS
{

  "commandToExecute": "sudo apt-get update && apt-get install -y apache2 && echo 'hello world' > /var/www/html/index.html"
}
SETTINGS
}