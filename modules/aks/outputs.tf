output "aks_vnet_id" {
  description = "ID de la vnet du cluster AKS"
  value       = data.azurerm_virtual_network.aks_vnet.id
}

output "vnet_subnet_id" {
  description = "ID du sous-réseau du cluster AKS"
  value       = data.azurerm_subnet.aks_subnet.id
}

output "aks_kubelet_identity_object_id" {
  description = "Object ID de l'identité du kubelet du cluster AKS"
  value       = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
}
