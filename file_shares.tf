# Fetch your local machine's public IP address
data "http" "ip" {
  url = "https://ipv4.icanhazip.com"
}

# Generate a unique suffix for the finance storage account
resource "random_string" "finance_suffix" {
  length  = 6
  special = false
  upper   = false
}

# 1. Create the Virtual Network and Subnet with Service Endpoints
resource "azurerm_virtual_network" "finance_vnet" {
  name                = "finance-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "finance_subnet" {
  name                 = "default"
  resource_group_name  = data.azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.finance_vnet.name
  address_prefixes     = ["10.0.1.0/24"]

  # Crucial: Enables the subnet to securely route traffic to Azure Storage
  service_endpoints = ["Microsoft.Storage"]
}

# 2. Create the Premium File Storage Account
resource "azurerm_storage_account" "finance_sa" {
  name                = "finance${random_string.finance_suffix.result}"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location

  # Required settings for Premium File Shares
  account_tier             = "Premium"
  account_kind             = "FileStorage"
  account_replication_type = "ZRS"

  # Restrict access to the specific subnet
  network_rules {
    default_action             = "Deny"
    virtual_network_subnet_ids = [azurerm_subnet.finance_subnet.id]

    # Whitelists your local IP so Terraform can configure the file share
    ip_rules = [chomp(data.http.ip.response_body)]
  }
}

# 3. Create the File Share
resource "azurerm_storage_share" "corp_share" {
  name                 = "corpshare"
  storage_account_name = azurerm_storage_account.finance_sa.name

  # Premium file shares require a provisioned quota (minimum 100 GB)
  quota = 100
}

# 4. Create the Directory inside the File Share
#resource "azurerm_storage_share_directory" "finance_dir" {
#  name                 = "finance"
#  share_name           = azurerm_storage_share.corp_share.name
#  storage_account_name = azurerm_storage_account.finance_sa.name
#}