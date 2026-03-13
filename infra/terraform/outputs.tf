output "resource_group" {
  description = "Resource group name"
  value       = azurerm_resource_group.main.name
}

output "frontend_url" {
  description = "Frontend App Service URL"
  value       = "https://${azurerm_linux_web_app.frontend.default_hostname}"
}

output "backend_url" {
  description = "Backend Function App URL"
  value       = "https://${azurerm_linux_function_app.backend.default_hostname}"
}

output "email_url" {
  description = "Email Processing Function App URL"
  value       = "https://${azurerm_linux_function_app.email.default_hostname}"
}

output "cosmos_endpoint" {
  description = "Cosmos DB endpoint"
  value       = azurerm_cosmosdb_account.main.endpoint
}

output "servicebus_hostname" {
  description = "Service Bus namespace hostname"
  value       = "${azurerm_servicebus_namespace.main.name}.servicebus.windows.net"
}

output "keyvault_uri" {
  description = "Key Vault URI"
  value       = azurerm_key_vault.main.vault_uri
}

output "storage_account_name" {
  description = "Storage account used by Functions"
  value       = azurerm_storage_account.main.name
}
