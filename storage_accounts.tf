resource "azurerm_storage_account" "training_sa" {
  name                = "storagetest${random_string.suffix.result}"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location

  # Basic Settings
  account_tier             = "Standard"
  account_replication_type = "LRS" # Lowest cost, no high availability required

  # Security and Networking Configurations
  https_traffic_only_enabled    = true     # Maps to "Secure transfer required: Enabled"
  min_tls_version               = "TLS1_2" # Maps to "Minimal TLS version: 1.2"
  shared_access_key_enabled     = false    # Maps to "Allow storage account key access: Disabled"
  public_network_access_enabled = true     # Maps to "Public network access: Enabled from all networks"
}