# == URLs ======================================================================
output "frontend_url" {
  value       = "https://${azurerm_static_web_app.frontend.default_host_name}"
  description = "Frontend Static Web App URL"
}

output "frontend_deploy_token" {
  value       = azurerm_static_web_app.frontend.api_key
  sensitive   = true
  description = "SWA deploy token — auto-pushed to GitHub Actions via github_actions_secret"
}

output "backend_url" {
  value       = "https://${azurerm_linux_function_app.backend.default_hostname}/api"
  description = "Backend function app base URL"
}

# == Resource names ============================================================
output "backend_function_app_name" {
  value       = azurerm_linux_function_app.backend.name
  description = "func azure functionapp publish <n> --python"
}

output "email_function_app_name" {
  value       = azurerm_linux_function_app.email.name
  description = "func azure functionapp publish <n> --python"
}

output "resource_group_main" {
  value       = azurerm_resource_group.main.name
  description = "Main resource group"
}

output "resource_group_func" {
  value       = azurerm_resource_group.func.name
  description = "Functions resource group"
}

# == Cosmos ====================================================================
output "cosmos_endpoint" {
  value       = azurerm_cosmosdb_account.main.endpoint
  description = "COSMOS_ENDPOINT for local.settings.json"
}

output "cosmos_primary_key" {
  value       = azurerm_cosmosdb_account.main.primary_key
  sensitive   = true
  description = "Local dev only — Azure uses managed identity"
}

# == Service Bus ===============================================================
output "servicebus_connection_string" {
  value       = azurerm_servicebus_namespace_authorization_rule.apps.primary_connection_string
  sensitive   = true
  description = "SB_CONNECTION_STRING for local.settings.json (local dev only)"
}

output "servicebus_namespace" {
  value       = "${azurerm_servicebus_namespace.main.name}.servicebus.windows.net"
  description = "Fully qualified Service Bus namespace"
}

# == AI Foundry ================================================================
output "foundry_endpoint" {
  value       = azurerm_cognitive_account.foundry.endpoint
  description = "Azure AI Foundry endpoint"
}

output "foundry_model_name" {
  value       = var.foundry_model_name
  description = "OPENAI_MODEL_NAME for local.settings.json"
}

# == Key Vault =================================================================
output "key_vault_name" {
  value       = azurerm_key_vault.main.name
  description = "az keyvault secret list --vault-name <n>"
}

# == Observability =============================================================
output "log_analytics_workspace_id" {
  value       = azurerm_log_analytics_workspace.main.id
  description = "Log Analytics workspace for querying audit logs"
}
