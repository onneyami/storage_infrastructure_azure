# 1. Fetch details about your current Azure CLI login (Tenant ID and Object ID)
data "azurerm_client_config" "current" {}

resource "random_string" "app_suffix" {
  length  = 6
  special = false
  upper   = false
}

# 2. Create the User-Assigned Managed Identity
resource "azurerm_user_assigned_identity" "app_mi" {
  name                = "app-managed-identity"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
}

# 3. Create the Storage Account with Infrastructure Encryption Enabled
resource "azurerm_storage_account" "app_sa" {
  name                              = "secureapp${random_string.app_suffix.result}"
  resource_group_name               = data.azurerm_resource_group.rg.name
  location                          = data.azurerm_resource_group.rg.location
  account_tier                      = "Standard"
  account_replication_type          = "LRS"
  
  # Enable infrastructure encryption (cannot be changed after creation)
  infrastructure_encryption_enabled = true

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.app_mi.id]
  }
}

# 4. Assign Storage Blob Data Reader to the Managed Identity
resource "azurerm_role_assignment" "mi_storage_reader" {
  scope                = azurerm_storage_account.app_sa.id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = azurerm_user_assigned_identity.app_mi.principal_id
}

# 5. Create the Key Vault with Purge Protection and RBAC authorization
resource "azurerm_key_vault" "kv" {
  name                      = "appkv${random_string.app_suffix.result}"
  location                  = data.azurerm_resource_group.rg.location
  resource_group_name       = data.azurerm_resource_group.rg.name
  tenant_id                 = data.azurerm_client_config.current.tenant_id
  sku_name                  = "standard"
  
  enable_rbac_authorization = true
  purge_protection_enabled  = true
}

# 6. Assign Key Vault Administrator to the user running Terraform (You)
resource "azurerm_role_assignment" "tf_kv_admin" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}

# 7. Assign Key Vault Crypto Service Encryption User to the Managed Identity
resource "azurerm_role_assignment" "mi_kv_crypto" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Crypto Service Encryption User"
  principal_id         = azurerm_user_assigned_identity.app_mi.principal_id
}

# 8. Wait for Azure AD RBAC propagation
# Azure takes time to apply RBAC roles. If Terraform tries to create the key immediately, it will fail.
resource "time_sleep" "wait_for_rbac" {
  create_duration = "90s"
  depends_on = [
    azurerm_role_assignment.tf_kv_admin,
    azurerm_role_assignment.mi_kv_crypto
  ]
}

# 9. Create the Customer Managed Key (CMK) in Key Vault
resource "azurerm_key_vault_key" "cmk" {
  name         = "storage-cmk"
  key_vault_id = azurerm_key_vault.kv.id
  key_type     = "RSA"
  key_size     = 2048
  key_opts     = ["decrypt", "encrypt", "sign", "unwrapKey", "verify", "wrapKey"]

  # Do not create the key until the 90-second RBAC delay finishes
  depends_on = [time_sleep.wait_for_rbac] 
}

# 10. Link the Customer Managed Key to the Storage Account
resource "azurerm_storage_account_customer_managed_key" "app_sa_cmk" {
  storage_account_id        = azurerm_storage_account.app_sa.id
  key_vault_id              = azurerm_key_vault.kv.id
  key_name                  = azurerm_key_vault_key.cmk.name
  user_assigned_identity_id = azurerm_user_assigned_identity.app_mi.id
}

# 11. Create the container for Immutability testing
resource "azurerm_storage_container" "hold_container" {
  name                  = "hold"
  storage_account_name  = azurerm_storage_account.app_sa.name
  container_access_type = "private"
}

# 12. Apply the 5-day Time-Based Retention Policy
resource "azurerm_storage_container_immutability_policy" "hold_policy" {
  storage_container_resource_manager_id = azurerm_storage_container.hold_container.resource_manager_id
  immutability_period_in_days           = 5
  protected_append_writes_all_enabled   = false
  protected_append_writes_enabled       = false
}

# 13. Create the Encryption Scope (Infrastructure Encryption)
resource "azurerm_storage_encryption_scope" "infra_scope" {
  name                               = "infrascope"
  storage_account_id                 = azurerm_storage_account.app_sa.id
  source                             = "Microsoft.Storage"
  infrastructure_encryption_required = true
}