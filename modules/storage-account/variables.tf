# storage-account variables

variable "owner" { type = string }
variable "resource_group_name" { type = string }
variable "node_resource_group_name" { type = string }
variable "location" { type = string }
variable "tags" { type = map(string) }
variable "aks_subnet_id" {
  type        = string
  description = "L'ID du sous-réseau AKS pour les règles d'accès réseau"
}

variable "aks_vnet_id" {
  type        = string
  description = "L'ID du Vnet"
}
variable "key_vault_access_policy_id" {
  type        = string
  description = "L'ID de la politique d'accès au Key Vault pour le stockage"
}

variable "key_vault_key_id" {
  type        = string
  description = "L'ID de la clé du Key Vault pour le stockage"
}

variable "user_assigned_identity_id" {
  type        = string
  description = "L'ID de l'identité assignée pour le stockage"
}
