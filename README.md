This is a Terraform Module for create one or multiple Windows VM's in Azure. With working WINRM. So you can start using Ansible or Powershell to configurate your VM. :) 

## Usage

```hcl
module "terraform-windows" {
    source = https://github.com/philipphomberger/terraform-windows
    username = "Administrator"
    password = "tedjkjchjik11!"
    location = "West US 2"
    anzahl   = "2"
    vm_name  = "testwindows"
}
```
