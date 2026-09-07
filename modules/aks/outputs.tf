output "aks_vnet_id" {
  description = "ID de la vnet du cluster AKS"
  value       = data.azurerm_virtual_network.aks_vnet.id
}

output "vnet_subnet_id" {
  description = "ID du sous-réseau du cluster AKS"
  value       = data.azurerm_subnet.aks_subnet.id
}
