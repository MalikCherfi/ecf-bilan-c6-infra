# keyvault module

# Get current identity information
data "azurerm_client_config" "current" {}

# Key Vault for encryption keys
resource "azurerm_key_vault" "storage" {
  name                        = "kv-storage-encrypt-mc"
  location                    = var.location
  resource_group_name         = var.resource_group_name
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  sku_name                    = "standard"
  enabled_for_disk_encryption = false
  purge_protection_enabled    = true # Required for CMK encryption
  soft_delete_retention_days  = 7
  tags                        = var.tags

  # Network rules for additional security
  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
    ip_rules       = ["92.184.110.0/24"] # office IP
  }
}

# Access policy for the current user/service principal
resource "azurerm_key_vault_access_policy" "admin" {
  key_vault_id = azurerm_key_vault.storage.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  key_permissions = [
    "Get", "List", "Create", "Delete", "Update",
    "Recover", "Purge", "GetRotationPolicy", "SetRotationPolicy"
  ]
}

# Encryption key for storage account
resource "azurerm_key_vault_key" "storage" {
  name         = "storage-key"
  key_vault_id = azurerm_key_vault.storage.id
  key_type     = "RSA"
  key_size     = 2048

  key_opts = [
    "decrypt",
    "encrypt",
    "sign",
    "unwrapKey",
    "verify",
    "wrapKey"
  ]

  # Automatic key rotation
  rotation_policy {
    automatic {
      time_before_expiry = "P30D" # Rotate 30 days before expiry
    }
    expire_after         = "P365D" # Key expires after 1 year
    notify_before_expiry = "P30D"
  }

  depends_on = [azurerm_key_vault_access_policy.admin]
}

# Managed identity for the storage account
resource "azurerm_user_assigned_identity" "backup_storage" {
  name                = "id-backup-storage"
  location            = var.location
  resource_group_name = var.resource_group_name
}

# Grant the managed identity access to Key Vault keys
resource "azurerm_key_vault_access_policy" "storage" {
  key_vault_id = azurerm_key_vault.storage.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_user_assigned_identity.backup_storage.principal_id

  key_permissions = [
    "Get", "UnwrapKey", "WrapKey"
  ]
}
