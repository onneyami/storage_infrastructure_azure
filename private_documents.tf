# Generate a unique suffix for the private storage account
resource "random_string" "private_suffix" {
  length  = 6
  special = false
  upper   = false
}

# 1. Create the Private Storage Account with GRS
resource "azurerm_storage_account" "private_sa" {
  name                     = "privatedocs${random_string.private_suffix.result}"
  resource_group_name      = data.azurerm_resource_group.rg.name
  location                 = data.azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "GRS" # Geo-redundant storage (no read access to secondary)

  blob_properties {
    # Versioning is strictly required on the destination account for Object Replication to work
    versioning_enabled = true
    change_feed_enabled = true
  }
}

# 2. Create the private storage container
resource "azurerm_storage_container" "private_container" {
  name                  = "private"
  storage_account_name  = azurerm_storage_account.private_sa.name
  container_access_type = "private" # No anonymous access allowed
}

# 3. Create the backup storage container for object replication
resource "azurerm_storage_container" "backup_container" {
  name                  = "backup"
  storage_account_name  = azurerm_storage_account.private_sa.name
  container_access_type = "private"
}

# 4. Configure Lifecycle Management (Move to Cool after 30 days)
resource "azurerm_storage_management_policy" "lifecycle" {
  storage_account_id = azurerm_storage_account.private_sa.id

  rule {
    name    = "movetocool"
    enabled = true
    filters {
      blob_types = ["blockBlob"]
      # Leaving out prefix_match applies this rule to ALL blobs in the storage account
    }
    actions {
      base_blob {
        tier_to_cool_after_days_since_modification_greater_than = 30
      }
    }
  }
}

# 5. Configure Object Replication (Public -> Private)
# This references the public_sa and public_container created in your previous public_website.tf file
resource "azurerm_storage_object_replication" "repl" {
  source_storage_account_id      = azurerm_storage_account.public_sa.id
  destination_storage_account_id = azurerm_storage_account.private_sa.id

  rules {
    source_container_name      = azurerm_storage_container.public_container.name
    destination_container_name = azurerm_storage_container.backup_container.name
  }
}