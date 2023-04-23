terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "=2.91.0"
    }
  }
}

provider "azurerm" {
    features {}
    subscription_id = "8427562f-8418-42ba-bd2d-f267f0f59639"
    client_id       = "43f51cb4-790e-4001-b469-9a0f946db138"
    client_secret   = "SaS8Q~v5pImVPEi70kDAISSHrVL0JOAD2M~ticNi"
    tenant_id       = "aa60563d-ee7f-4224-bfb1-b4b18151ed8a"
}

# variable "vm_csv_file_path" {
#   description = "vm.csv"
# }

locals {
  vm_details    = csvdecode(file("vm.csv"))
}


# Retrieve the Resource Group details
data "azurerm_resource_group" "rg" {
  name = var.resource_group_name
}

output rg_name {
    value = {
      name     = data.azurerm_resource_group.rg.name
      location = data.azurerm_resource_group.rg.location
  }
}

# Retrieve the Virtual Network details
data "azurerm_virtual_network" "vnet" {
  name                = var.virtual_network_name
  resource_group_name = data.azurerm_resource_group.rg.name
}

output vnet_name {
    value = {
      name     = data.azurerm_virtual_network.vnet.name
      location = data.azurerm_virtual_network.vnet.location
  }
}

# Retrieve the Subnet details
data "azurerm_subnet" "snet" {
  name                 = var.snet_name
  virtual_network_name = data.azurerm_virtual_network.vnet.name
  resource_group_name  = data.azurerm_resource_group.rg.name
}

output snet_name {
    value = {
      name     = data.azurerm_subnet.snet.name
  }
}

resource "azurerm_public_ip" "publicip" {
  count               = "${length(local.vm_details)}"
  name                         = "${local.vm_details[count.index]["publicIP"]}"
  location                     = "${local.vm_details[count.index]["location"]}"
  resource_group_name          = "${data.azurerm_resource_group.rg.name}"
  allocation_method            = "Static"
  idle_timeout_in_minutes      = 15
}

output "public_ip_addresses" {
  value = [for ip in azurerm_public_ip.publicip : ip.ip_address]
}

resource "azurerm_network_interface" "vm_nic" {
  count               = "${length(local.vm_details)}"
  name                = "${local.vm_details[count.index]["nic_name"]}"
  location            = "${local.vm_details[count.index]["location"]}"
  resource_group_name = "${data.azurerm_resource_group.rg.name}"

  ip_configuration {
    name                          = "${local.vm_details[count.index]["ip_config_name"]}"
    subnet_id                     = "${data.azurerm_subnet.snet.id}"
    private_ip_address_allocation = "static"
    private_ip_address            = "${local.vm_details[count.index]["private_ip"]}"
    private_ip_address_version    = "${local.vm_details[count.index]["proivate_ip_version"]}"
    public_ip_address_id          = "${azurerm_public_ip.publicip.*.id[count.index]}"
  }
}

resource "azurerm_linux_virtual_machine" "vm" {
  count               = "${length(local.vm_details)}"
  name                = "${local.vm_details[count.index]["vm_name"]}"
  location            = "${local.vm_details[count.index]["location"]}"
  resource_group_name = "${data.azurerm_resource_group.rg.name}"
  network_interface_ids = [
    "${azurerm_network_interface.vm_nic.*.id[count.index]}"
  ]
  size                = "${local.vm_details[count.index]["vm_size"]}"
  admin_username      = "${local.vm_details[count.index]["vm_admin_username"]}"
  admin_password      = "${local.vm_details[count.index]["vm_admin_password"]}"
  disable_password_authentication = "false"
  os_disk {
    name              = "${local.vm_details[count.index]["os_disk_name"]}"
    caching           = "ReadWrite"
    storage_account_type = "${local.vm_details[count.index]["os_disk_storage_type"]}"
  }
  source_image_reference {
    publisher = "${local.vm_details[count.index]["os_publisher"]}"
    offer     = "${local.vm_details[count.index]["os_offer"]}"
    sku       = "${local.vm_details[count.index]["os_sku"]}"
    version   = "latest"
  }
}

resource "null_resource" "shell" {

  provisioner "local-exec" {
    command = "terraform output public_ip_addresses > public_ips.txt"
  }
  depends_on = [
    azurerm_linux_virtual_machine.vm
  ]
}

# data "azurerm_public_ip" "ecapublicip" {
#   count = length(var.vm_names)
#   name  = "example-${var.vm_names[count.index]}-public-ip"
#   resource_group_name = azurerm_resource_group.example.name
# }

# locals {
#   vm_public_ips = [for ip in data.azurerm_public_ip.example.*.ip_address : ip]
# }

# resource "local_file" "vm_public_ips" {
#   content  = yamlencode({public_ips = local.vm_public_ips})
#   filename = "vm_public_ips.yml"
# }

