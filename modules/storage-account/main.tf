# --- Storage Account File Share ---

data "azurerm_client_config" "current" {}

# --- Storage Account for NFS / SMB ---
resource "azurerm_storage_account" "sa_fs" {
  name                     = "samcherfifs"
  resource_group_name      = "mcherfiRG"
  location                 = "francecentral"
  account_tier             = "Premium"
  account_kind             = "FileStorage"
  account_replication_type = "LRS"

  https_traffic_only_enabled    = false
  public_network_access_enabled = false

  azure_files_authentication {
    directory_type = "AADKERB"
  }
}

# --- NFS file share for Postgres ---
resource "azurerm_storage_share" "postgres_share" {
  name               = "postgres-data"
  storage_account_id = azurerm_storage_account.sa_fs.id
  quota              = 100
  enabled_protocol   = "NFS"
}

# --- SMB file share for Employes ---
resource "azurerm_storage_share" "employes_share" {
  name               = "employes-data"
  storage_account_id = azurerm_storage_account.sa_fs.id
  quota              = 100
  enabled_protocol   = "SMB"
}

# --- Access role for Employes ---
resource "azurerm_role_assignment" "employes_smb_access" {
  scope                = azurerm_storage_account.sa_fs.id
  role_definition_name = "Storage File Data SMB Share Contributor"
  principal_id         = var.employes_group_object_id

  depends_on = [var.employes_group_object_id]
}

# --- Private Endpoint & Private Zone DNS ---
resource "azurerm_private_dns_zone" "dns_file" {
  name                = "privatelink.file.core.windows.net"
  resource_group_name = "mcherfiRG"
}


# --- Link the Private DNS Zone to the AKS VNet ---
resource "azurerm_private_dns_zone_virtual_network_link" "vnet_link" {
  name                  = "link-aks-vnet"
  resource_group_name   = "mcherfiRG"
  private_dns_zone_name = azurerm_private_dns_zone.dns_file.name
  virtual_network_id    = var.aks_vnet_id

  depends_on = [var.aks_vnet_id]
}


# --- Private Endpoint for NFS File Share ---
resource "azurerm_private_endpoint" "nfs_pe" {
  name                = "pe-storage-postgres-nfs"
  location            = "francecentral"
  resource_group_name = "mcherfiRG"
  subnet_id           = var.aks_subnet_id

  private_service_connection {
    name                           = "psc-storage-nfs"
    private_connection_resource_id = azurerm_storage_account.sa_fs.id
    is_manual_connection           = false
    subresource_names              = ["file"]
  }

  private_dns_zone_group {
    name                 = "dns-group-file"
    private_dns_zone_ids = [azurerm_private_dns_zone.dns_file.id]
  }

  depends_on = [var.aks_subnet_id]
}


# --- Velero Backup Storage Account with Customer Managed Key (CMK) Encryption ---

resource "azurerm_storage_account" "sa_velero" {
  name                            = "samcherfivelero"
  resource_group_name             = var.resource_group_name
  location                        = var.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  account_kind                    = "StorageV2"
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = true
  shared_access_key_enabled       = true
  tags                            = var.tags

  network_rules {
    default_action             = "Deny"
    bypass                     = ["AzureServices"]
    ip_rules                   = ["92.184.110.215"]
    virtual_network_subnet_ids = [var.aks_subnet_id]
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [var.user_assigned_identity_id]
  }

  customer_managed_key {
    key_vault_key_id          = var.key_vault_key_id
    user_assigned_identity_id = var.user_assigned_identity_id
  }

  blob_properties {
    versioning_enabled  = true
    change_feed_enabled = true

    container_delete_retention_policy {
      days = 7
    }
  }
}

resource "azurerm_storage_container" "velero" {
  name                  = "velero"
  storage_account_id    = azurerm_storage_account.sa_velero.id
  container_access_type = "private"

  depends_on = [azurerm_storage_account.sa_velero]
}

resource "azurerm_role_assignment" "storage_blob_data_contributor" {
  scope                = azurerm_storage_account.sa_velero.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}

