output "database_url" {
  value       = "${azurerm_mysql_flexible_server.database.fqdn}:3306/${azurerm_mysql_flexible_database.database.name}"
  description = "The MySQL server URL."
}

output "database_username" {
  value       = var.administrator_login
  description = "The MySQL server user name."
}

output "database_password" {
  value       = random_password.password.result
  sensitive   = true
  description = "The MySQL server password."
}

output "database_name" {
  value       = azurerm_mysql_flexible_database.database.name
  description = "The MySQL database name."
}

output "server_fqdn" {
  value       = azurerm_mysql_flexible_server.database.fqdn
  description = "The MySQL server FQDN."
}

output "server_name" {
  value = azurerm_mysql_flexible_server.database.name
  description = "The MySQL server name."  
}