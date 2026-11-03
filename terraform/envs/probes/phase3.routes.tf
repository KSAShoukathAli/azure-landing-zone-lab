# These resources deliberately live in the EXISTING Phase 2 (probes) root.
# The subnets and NICs are already managed by that same state.
# Do not put duplicate subnet/NIC resources in a separate Phase 3 Terraform state.

resource "azurerm_route_table" "phase3_spoke1" {
  count               = var.phase3_enable_spoke1_route ? 1 : 0
  name                = "rt-phase3-spoke1-to-spoke2-cac"
  location            = data.azurerm_resource_group.existing["spoke1"].location
  resource_group_name = data.azurerm_resource_group.existing["spoke1"].name
  tags                = local.common_tags
}

resource "azurerm_route" "phase3_spoke1_to_spoke2" {
  count                  = var.phase3_enable_spoke1_route ? 1 : 0
  name                   = "spoke2-via-hub"
  resource_group_name    = data.azurerm_resource_group.existing["spoke1"].name
  route_table_name       = azurerm_route_table.phase3_spoke1[0].name
  address_prefix         = "10.62.0.0/16"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = local.locations["hub"].vm_ip
}

resource "azurerm_subnet_route_table_association" "phase3_spoke1" {
  count          = var.phase3_enable_spoke1_route ? 1 : 0
  subnet_id      = azurerm_subnet.probe["spoke1"].id
  route_table_id = azurerm_route_table.phase3_spoke1[0].id
  depends_on     = [azurerm_route.phase3_spoke1_to_spoke2]
}

resource "azurerm_route_table" "phase3_spoke2" {
  count               = var.phase3_enable_spoke2_route ? 1 : 0
  name                = "rt-phase3-spoke2-to-spoke1-cac"
  location            = data.azurerm_resource_group.existing["spoke2"].location
  resource_group_name = data.azurerm_resource_group.existing["spoke2"].name
  tags                = local.common_tags
}

resource "azurerm_route" "phase3_spoke2_to_spoke1" {
  count                  = var.phase3_enable_spoke2_route ? 1 : 0
  name                   = "spoke1-via-hub"
  resource_group_name    = data.azurerm_resource_group.existing["spoke2"].name
  route_table_name       = azurerm_route_table.phase3_spoke2[0].name
  address_prefix         = "10.61.0.0/16"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = local.locations["hub"].vm_ip
}

resource "azurerm_subnet_route_table_association" "phase3_spoke2" {
  count          = var.phase3_enable_spoke2_route ? 1 : 0
  subnet_id      = azurerm_subnet.probe["spoke2"].id
  route_table_id = azurerm_route_table.phase3_spoke2[0].id
  depends_on     = [azurerm_route.phase3_spoke2_to_spoke1]
}
