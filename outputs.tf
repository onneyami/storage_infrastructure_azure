output "resource_group_name" {
  description = "The name of the resource group"
  value       = data.azurerm_resource_group.rg.name
}

# Output the URL of the uploaded blob
#output "test_blob_url" {
#  description = "The public URL of the uploaded test blob"
#  value       = azurerm_storage_blob.test_upload.url
#}