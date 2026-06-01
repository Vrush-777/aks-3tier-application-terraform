# PostgreSQL Module - outputs.tf

output "postgres_id" {
  description = "ID of the PostgreSQL server"
  value       = azurerm_postgresql_flexible_server.postgres.id
}

output "postgres_fqdn" {
  description = "FQDN of the PostgreSQL server"
  value       = azurerm_postgresql_flexible_server.postgres.fqdn
}

output "postgres_name" {
  description = "Name of the PostgreSQL server"
  value       = azurerm_postgresql_flexible_server.postgres.name
}

output "postgres_admin_username" {
  description = "Administrator username for PostgreSQL"
  value       = azurerm_postgresql_flexible_server.postgres.administrator_login
}

output "database_name" {
  description = "Name of the created database"
  value       = azurerm_postgresql_flexible_server_database.database.name
}

output "postgres_version" {
  description = "PostgreSQL version"
  value       = azurerm_postgresql_flexible_server.postgres.version
}

output "postgres_private_dns_zone_id" {
  description = "ID of the private DNS zone for PostgreSQL"
  value       = azurerm_private_dns_zone.postgres_dns.id
}

output "connection_string" {
  description = "PostgreSQL connection string (without password)"
  value       = "postgresql://${azurerm_postgresql_flexible_server.postgres.administrator_login}@${azurerm_postgresql_flexible_server.postgres.fqdn}/${azurerm_postgresql_flexible_server_database.database.name}"
}
