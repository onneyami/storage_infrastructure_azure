# Generate a unique suffix for the public storage account
resource "random_string" "public_suffix" {
  length  = 6
  special = false
  upper   = false
}

# Create the storage account with RA-GRS, public access, soft delete, and versioning
resource "azurerm_storage_account" "public_sa" {
  name                     = "pubweb${random_string.public_suffix.result}"
  resource_group_name      = data.azurerm_resource_group.rg.name
  location                 = data.azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "RAGRS"

  allow_nested_items_to_be_public = true

  blob_properties {
    versioning_enabled = true

    delete_retention_policy {
      days = 21
    }
  }
}

# Create the blob storage container with anonymous read access
resource "azurerm_storage_container" "public_container" {
  name                  = "public"
  storage_account_name  = azurerm_storage_account.public_sa.name
  container_access_type = "blob"
}

# Upload a test file
resource "azurerm_storage_blob" "test_upload" {
  name                   = "hello-world.txt"
  storage_account_name   = azurerm_storage_account.public_sa.name
  storage_container_name = azurerm_storage_container.public_container.name
  type                   = "Block"
  source_content         = "Hello, this is a test file for the public website!"
}