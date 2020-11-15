resource "azurerm_windows_virtual_machine" "vm" {
  name                  = local.vm_name
  location              = var.location
  resource_group_name   = var.resource_group_name
  network_interface_ids = [azurerm_network_interface.nic.id]
  size                  = var.vm_size
  license_type          = var.license_type

  tags = merge(local.default_tags, local.default_vm_tags, var.extra_tags)

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  computer_name  = local.vm_name
  admin_username = var.admin_username
  admin_password = var.admin_password
  custom_data    = base64encode(local.custom_data_content)

  secret {
    key_vault_id = var.key_vault_id

    certificate {
      url   = azurerm_key_vault_certificate.winrm_certificate.secret_id
      store = "My"
    }
  }

  provision_vm_agent       = true
  enable_automatic_updates = true

  # Auto-Login's required to configure WinRM
  additional_unattend_content {
    setting = "AutoLogon"
    content = "<AutoLogon><Password><Value>${local.admin_password_encoded}</Value></Password><Enabled>true</Enabled><LogonCount>1</LogonCount><Username>${var.admin_username}</Username></AutoLogon>"
  }

  # Unattend config is to enable basic auth in WinRM, required for the provisioner stage.
  additional_unattend_content {
    setting = "FirstLogonCommands"
    content = file(format("%s/files/FirstLogonCommands.xml", path.module))
  }

  identity {
    type = "SystemAssigned"
  }
}

resource "null_resource" "winrm_connection_test" {
  count = var.public_ip_sku == null ? 0 : 1

  depends_on = [
    azurerm_network_interface.nic,
    azurerm_public_ip.public_ip,
    azurerm_windows_virtual_machine.vm,
  ]

  triggers = {
    uuid = azurerm_windows_virtual_machine.vm.id
  }

  connection {
    type     = "winrm"
    host     = join("", azurerm_public_ip.public_ip.*.ip_address)
    port     = 5986
    https    = true
    user     = var.admin_username
    password = var.admin_password
    timeout  = "3m"

    # NOTE: if you're using a real certificate, rather than a self-signed one, you'll want this set to `false`/to remove this.
    insecure = true
  }

  provisioner "remote-exec" {
    inline = [
      "cd C:\\claranet",
      "dir",
    ]
  }
}