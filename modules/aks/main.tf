resource "azurerm_kubernetes_cluster" "aks" {
  name                      = "malik-aks-cluster-fr"
  location                  = "francecentral"
  resource_group_name       = var.resource_group_name
  dns_prefix                = "malikcherfi-aks-dns"
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  default_node_pool {
    name                         = "default"
    node_count                   = 1
    vm_size                      = "Standard_D2_v3"
    temporary_name_for_rotation  = "temp"
    only_critical_addons_enabled = false
  }

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

data "azurerm_virtual_network" "aks_vnet" {
  name                = "aks-vnet-15161255"
  resource_group_name = var.node_resource_group_name
}

data "azurerm_subnet" "aks_subnet" {
  name                 = "aks-subnet"
  virtual_network_name = data.azurerm_virtual_network.aks_vnet.name
  resource_group_name  = azurerm_kubernetes_cluster.aks.node_resource_group

  depends_on = [azurerm_kubernetes_cluster.aks, data.azurerm_virtual_network.aks_vnet]
}