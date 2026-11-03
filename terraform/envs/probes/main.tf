terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

# AzureRM 4.x uses ARM_SUBSCRIPTION_ID from the shell.
provider "azurerm" {
  features {}
}

# These are existing Phase 1 networks. The data sources READ them.
# This separate Terraform root does not own or destroy Phase 1 resources.
locals {
  locations = {
    hub = {
      resource_group = "rg-hubspoke-hub-cac"
      vnet_name      = "vnet-hub-cac"
      subnet_cidr    = "10.60.1.0/24"
      vm_ip          = "10.60.1.4"
    }
    spoke1 = {
      resource_group = "rg-hubspoke-spoke1-cac"
      vnet_name      = "vnet-spoke1-cac"
      subnet_cidr    = "10.61.1.0/24"
      vm_ip          = "10.61.1.4"
    }
    spoke2 = {
      resource_group = "rg-hubspoke-spoke2-cac"
      vnet_name      = "vnet-spoke2-cac"
      subnet_cidr    = "10.62.1.0/24"
      vm_ip          = "10.62.1.4"
    }
  }
  common_tags = {
    purpose    = "landing-zone-lab"
    phase      = "01-2-disposable"
    managed_by = "terraform"
  }
}

data "azurerm_resource_group" "existing" {
  for_each = local.locations
  name     = each.value.resource_group
}

data "azurerm_virtual_network" "existing" {
  for_each            = local.locations
  name                = each.value.vnet_name
  resource_group_name = data.azurerm_resource_group.existing[each.key].name
}

# One small subnet per existing VNet.
resource "azurerm_subnet" "probe" {
  for_each             = local.locations
  name                 = "snet-probe-${each.key}"
  resource_group_name  = data.azurerm_resource_group.existing[each.key].name
  virtual_network_name = data.azurerm_virtual_network.existing[each.key].name
  address_prefixes     = [each.value.subnet_cidr]
}

# NICs have private IP addresses only. No Public IP resources are created.
resource "azurerm_network_interface" "probe" {
  ip_forwarding_enabled = each.key == "hub" && var.phase3_enable_hub_forwarding
  for_each              = local.locations
  name                  = "nic-probe-${each.key}-cac"
  location              = data.azurerm_resource_group.existing[each.key].location
  resource_group_name   = data.azurerm_resource_group.existing[each.key].name
  tags                  = local.common_tags

  ip_configuration {
    name                          = "private"
    subnet_id                     = azurerm_subnet.probe[each.key].id
    private_ip_address_allocation = "Static"
    private_ip_address            = each.value.vm_ip
  }
}

# Cheap, short-lived test VMs. These incur compute + disk charges until destroyed.
# No NSG, UDR, firewall, NAT or public IP is added: inspect the baseline routing.
resource "azurerm_linux_virtual_machine" "probe" {
  for_each                        = local.locations
  name                            = "vm-probe-${each.key}-cac"
  computer_name                   = "probe-${each.key}"
  location                        = data.azurerm_resource_group.existing[each.key].location
  resource_group_name             = data.azurerm_resource_group.existing[each.key].name
  size                            = var.vm_size
  admin_username                  = "azurelab"
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.probe[each.key].id]
  tags                            = local.common_tags

  admin_ssh_key {
    username   = "azurelab"
    public_key = file(pathexpand(var.ssh_public_key_path))
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}