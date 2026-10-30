resource "azurerm_resource_group" "training_rg" {
  name     = "storagerg"
  location = "eastus" # Feel free to change this to your preferred region
}