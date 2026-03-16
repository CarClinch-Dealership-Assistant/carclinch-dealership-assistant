# == URLs ======================================================================
output "frontend_url" {
  value       = "https://${azurerm_static_web_app.frontend.default_host_name}"
  description = "Frontend SWA URL"
}

output "backend_url" {
  value       = "https://${azurerm_linux_function_app.backend.default_hostname}/api"
  description = "Backend function app base URL"
}

# == Resource names (useful for CLI commands) ==================================
output "backend_function_app_name" {
  value       = azurerm_linux_function_app.backend.name
  description = "Used in: func azure functionapp publish <name> --python"
}

output "email_function_app_name" {
  value       = azurerm_linux_function_app.email.name
  description = "Used in: func azure functionapp publish <name> --python"
}

output "resource_group_main" {
  value = azurerm_resource_group.main.name
}

output "resource_group_func" {
  value = azurerm_resource_group.func.name
}

# == Cosmos ====================================================================
output "cosmos_endpoint" {
  value       = azurerm_cosmosdb_account.main.endpoint
  description = "Set as COSMOS_ENDPOINT in local.settings.json for local dev (use key for auth locally)"
}

output "cosmos_primary_key" {
  value       = azurerm_cosmosdb_account.main.primary_key
  sensitive   = true
  description = "Use as COSMOS_CONNECTION_STRING locally; MI is used in Azure"
}

# == Service Bus ===============================================================
output "servicebus_connection_string" {
  value       = azurerm_servicebus_namespace_authorization_rule.apps.primary_connection_string
  sensitive   = true
  description = "Use as SB_CONNECTION_STRING in local.settings.json for local dev"
}

output "servicebus_namespace" {
  value       = "${azurerm_servicebus_namespace.main.name}.servicebus.windows.net"
  description = "Fully qualified Service Bus namespace"
}

# == AI Foundry ================================================================
output "foundry_endpoint" {
  value       = azurerm_cognitive_account.foundry.endpoint
  description = "Azure AI Foundry endpoint; auto-stored in Key Vault as OPENAI-BASE-URL"
}

output "foundry_model_name" {
  value       = var.foundry_model_name
  description = "Deployment name to use as OPENAI_MODEL_NAME in local.settings.json"
}

# == Key Vault =================================================================
output "key_vault_name" {
  value       = azurerm_key_vault.main.name
  description = "Key Vault name; useful for az keyvault secret list --vault-name <name>"
}
