variable "location" {
  default = "West US 2"
}

variable "username" {
  default = "philipp"
}

variable "password" {
  default = "philipp$1234"
}

variable "azurerm_public_ip_name" {
  default = "azurerm_public_ip_"
}

variable "azurerm_network_interface_name" {
  default = "azurerm_network_interface_"
}

variable "anzahl" {
  type    = number
  default = "1"
}

variable "vm_name" {
  default = "test_"
}

