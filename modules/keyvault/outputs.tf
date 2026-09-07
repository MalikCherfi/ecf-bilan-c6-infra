output "key_vault_access_policy_id" {
  description = "ID de la politique d'accès au Key Vault pour le stockage"
  value       = azurerm_key_vault_access_policy.storage.id
}

output "key_vault_key_id" {
  description = "ID sans version de la clé pour permettre la rotation automatique"
  value       = azurerm_key_vault_key.storage.versionless_id
}

output "user_assigned_identity_id" {
  description = "ID de l'identité assignée pour le stockage"
  value       = azurerm_user_assigned_identity.backup_storage.id
}