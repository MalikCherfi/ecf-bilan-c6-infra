output "vnet_subnet_id" {
  description = "ID du sous-réseau du cluster AKS"
  value       = data.azurerm_subnet.aks_subnet.id
}

output "aks_vnet_name" {
  description = "Le nom de la vnet du cluster AKS"
  value       = data.azurerm_resources.aks_vnet.name
}
