output "aks_vnet_id" {
  description = "ID de la vnet du cluster AKS"
  value       = data.azurerm_virtual_network.aks_vnet.id
}

output "vnet_subnet_id" {
  description = "ID du sous-réseau du cluster AKS"
  value       = data.azurerm_subnet.aks_subnet.id
}

output "aks_kubelet_identity_principal_id" {
  description = "Principal ID de l'identité du kubelet du cluster AKS"
  value       = azurerm_kubernetes_cluster.aks.identity[0].principal_id
}
