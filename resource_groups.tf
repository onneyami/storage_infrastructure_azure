resource "azurerm_resource_group" "training_rg" {
  name     = var.resource_group_name
  location = "eastus" # Feel free to change this to your preferred region
}