output "resource_group" {
  value       = azurerm_resource_group.main.name
  description = "The resource group."
}

output "acr_name" {
  value       = module.acr.registry_name
  description = "The name of the container registry."
}

output "cluster_name" {
  value       = module.service.cluster_name
  description = "The name of the AKS cluster."
}

output "cluster_fqdn" {
  value       = module.service.cluster_fqdn
  description = "The FQDN of the AKS cluster."
}

output "database_url" {
  value       = module.database.database_url
  description = "The JDBC URL to connect to the MySQL database"
}

output "database_server_fqdn" {
  value       = module.database.server_fqdn
  description = "The FQDN of the MySQL database"
}

output "database_server_name" {
  value       = module.database.server_name
  description = "The FQDN of the MySQL database"
}

output "database_name" {
  value       = module.database.database_name
  description = "The name of the MySQL database"
}