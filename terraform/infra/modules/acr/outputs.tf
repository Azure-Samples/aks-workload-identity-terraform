output "acr_id" {
  value       = azurerm_container_registry.acr.id
  description = "Container registry resource ID"
}

output "registry_name" {
  value       = azurerm_container_registry.acr.name
  description = "Azure Container Registry name"
}
