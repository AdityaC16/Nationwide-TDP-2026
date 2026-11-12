output "resource_group_name" {
  value = azurerm_resource_group.main.name
}

output "app_url" {
  value = "https://${azurerm_linux_web_app.main.default_hostname}"
}

output "database_name" {
  value = azurerm_mssql_database.main.name
}
