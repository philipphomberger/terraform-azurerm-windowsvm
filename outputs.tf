output "Computername" {
  value = azurerm_windows_virtual_machine.vm[*].name
}

output "Password" {
  value = random_password.password.result
}



