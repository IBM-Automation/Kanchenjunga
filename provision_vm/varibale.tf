variable "resource_group_name" {
    description = "resourcegroup"
    type = string
    default = "ECA-Ansible"
}

variable "virtual_network_name" {
    description = "virtualnet"
    type = string
    default = "eca-vnet"
}

variable "snet_name" {
    description = "subnet"
    type = string
    default = "eca-snet"
}