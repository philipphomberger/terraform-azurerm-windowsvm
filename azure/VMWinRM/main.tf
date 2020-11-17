resource "azurerm_resource_group" "resourceGroup" {
  name     = "MindcrackerResourceGroup"
  location = "${var.location}"
}

resource "azurerm_public_ip" "publicip" {
  name                         = "azurerm_public_ip_${count.index}"
  count                        = var.anzahl
  location                     = "${var.location}"
  resource_group_name          = "${azurerm_resource_group.resourceGroup.name}"
  idle_timeout_in_minutes      = 30
  domain_name_label            = "mindcrackvm${count.index}"
  allocation_method            = "Dynamic"

}

resource "azurerm_virtual_network" "vnet" {
  name                = "mindcracknetwork"
  address_space       = ["10.0.0.0/16"]
  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.resourceGroup.name}"
}

resource "azurerm_network_security_group" "nsg" {
  name                = "mindcracknsg"
  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.resourceGroup.name}"

  security_rule {
    name                       = "HTTPS"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTP"
    priority                   = 1020
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "winrm"
    priority                   = 1010
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5985"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "winrm-out"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "5985"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "RDP"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  
}

resource "azurerm_subnet" "subnet" {
  name                 = "mindcracksubnet"
  resource_group_name  = "${azurerm_resource_group.resourceGroup.name}"
  virtual_network_name = "${azurerm_virtual_network.vnet.name}"
  address_prefix       = "10.0.2.0/24"
}

resource "azurerm_network_interface" "nic" {
  name                      = "netzwerkinterface${count.index}"
  count                     = var.anzahl
  location                  = "${var.location}"
  resource_group_name       = "${azurerm_resource_group.resourceGroup.name}"
  

  ip_configuration {
    name                          = "mindcrackconfiguration"
    subnet_id                     = "${azurerm_subnet.subnet.id}"
    private_ip_address_allocation = "dynamic"
    public_ip_address_id          = azurerm_public_ip.publicip[count.index].id
  }
}
resource "azurerm_network_interface_security_group_association" "example" {
  count                     = var.anzahl
  network_interface_id      = azurerm_network_interface.nic[count.index].id
  network_security_group_id = "${azurerm_network_security_group.nsg.id}"
}

resource "random_password" "password" {
  length = 8
  special = true
  override_special = "_%@"
}

resource "azurerm_windows_virtual_machine" "vm" {
  name                = "clouddev-${count.index}"
  count               = var.anzahl
  resource_group_name = azurerm_resource_group.resourceGroup.name
  location            = "${var.location}"
  size                = "Standard_A2"
  admin_username      = "${var.username}"
  admin_password      = random_password.password.result
  enable_automatic_updates = true
  provision_vm_agent  = true

  winrm_listener {
    protocol        = "Http" 
  }

  network_interface_ids = [element(azurerm_network_interface.nic.*.id, count.index)]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }
}

resource "azurerm_virtual_machine_extension" "software" {
  name                 = "install-software"
  count                = var.anzahl
  virtual_machine_id   = azurerm_windows_virtual_machine.vm[count.index].id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.9"

  protected_settings = <<SETTINGS
  {
    "commandToExecute": "powershell -command \"[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('${base64encode(data.template_file.tf.rendered)}')) | Out-File -filepath install.ps1\" && powershell -ExecutionPolicy Unrestricted -File install.ps1"
  }
  SETTINGS
}

data "template_file" "tf" {
    template = "${file("install.ps1")}"
} 

