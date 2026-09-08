locals {
  tags = merge(
    {
      managed_by  = "terraform"
      environment = "bilan-tp"
      owner       = "malik-cherfi"
    }
  )
}

data "azurerm_client_config" "current" {}

data "azurerm_resource_group" "rg" {
  name = "mcherfiRG"
}
module "aks" {
  source = "./modules/aks"

  owner                    = "malik-cherfi"
  resource_group_name      = data.azurerm_resource_group.rg.name
  location                 = data.azurerm_resource_group.rg.location
  tags                     = local.tags
  node_resource_group_name = var.node_resource_group_name
}
module "storage-account" {
  source = "./modules/storage-account"

  owner                          = "malik-cherfi"
  resource_group_name            = data.azurerm_resource_group.rg.name
  node_resource_group_name       = var.node_resource_group_name
  location                       = data.azurerm_resource_group.rg.location
  tags                           = local.tags
  key_vault_access_policy_id     = module.keyvault.key_vault_access_policy_id
  key_vault_key_id               = module.keyvault.key_vault_key_id
  user_assigned_identity_id      = module.keyvault.user_assigned_identity_id
  aks_vnet_id                    = module.aks.aks_vnet_id
  aks_subnet_id                  = module.aks.vnet_subnet_id
  employes_group_object_id       = var.employes_group_object_id
  aks_kubelet_identity_object_id = module.aks.aks_kubelet_identity_object_id

}

module "keyvault" {
  source = "./modules/keyvault"

  owner               = "malik-cherfi"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  tags                = local.tags
}
