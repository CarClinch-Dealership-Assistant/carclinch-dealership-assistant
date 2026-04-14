terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }
}

provider "github" {
  owner = "CarClinch-Dealership-Assistant"
  token = var.github_token
}

resource "github_actions_secret" "swa_token" {
  repository      = "form-frontend-service"
  secret_name     = "AZURE_STATIC_WEB_APPS_API_TOKEN"
  plaintext_value = azurerm_static_web_app.frontend.api_key
}

resource "github_actions_secret" "backend_url" {
  repository      = "form-frontend-service"
  secret_name     = "BACKEND_URL"
  plaintext_value = "https://${azurerm_linux_function_app.backend.default_hostname}/api"
}

# We will delete the purges in handover
provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
    cognitive_account {
      purge_soft_delete_on_destroy = true
    }
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

data "http" "my_public_ip" {
  url = "https://ifconfig.me/ip"
}

data "azurerm_client_config" "current" {}

# == Locals: naming + tags =====================================================
locals {
  p   = var.prefix
  env = var.environment
  loc = var.location

  tags = merge({
    environment = local.env
    project     = "carclinch"
    managed_by  = "terraform"
  }, var.tags)

  kv_name      = "${local.p}-kv-${local.env}"
  storage_name = substr("${local.p}st${local.env}", 0, 24)
}

# == Resource Groups ===========================================================
resource "azurerm_resource_group" "main" {
  name     = "${local.p}-rg-${local.env}"
  location = local.loc
  tags     = local.tags
}

# Kept separate bc Azure locks a RG's App Service feature set on first plan
# creation; mixing B1 Linux and Y1 Linux Consumption in one RG is rejected.
resource "azurerm_resource_group" "func" {
  name     = "${local.p}-func-rg-${local.env}"
  location = local.loc
  tags     = local.tags
}

# == Storage (required by Azure Functions) =====================================
resource "azurerm_storage_account" "main" {
  name                            = local.storage_name
  resource_group_name             = azurerm_resource_group.func.name
  location                        = azurerm_resource_group.func.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  https_traffic_only_enabled      = true
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  public_network_access_enabled   = true

  network_rules {
    default_action = "Allow"
    bypass         = ["AzureServices"]
  }

  tags = local.tags
}

# == Cosmos DB (serverless) ====================================================
resource "azurerm_cosmosdb_account" "main" {
  name                = "${local.p}-cosmos-${local.env}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"

  public_network_access_enabled = true

  ip_range_filter = [chomp(data.http.my_public_ip.response_body), "0.0.0.0"]

  capabilities { name = "EnableServerless" }

  consistency_policy { consistency_level = "Session" }

  geo_location {
    location          = azurerm_resource_group.main.location
    failover_priority = 0
  }

  tags = local.tags
}

resource "azurerm_cosmosdb_sql_database" "main" {
  name                = var.cosmos_db_name
  resource_group_name = azurerm_resource_group.main.name
  account_name        = azurerm_cosmosdb_account.main.name
}

# == Cosmos DB seed ============================================================
resource "null_resource" "cosmos_seed" {
  triggers = {
    cosmos_endpoint = azurerm_cosmosdb_account.main.endpoint
  }

  provisioner "local-exec" {
    command = "${var.pip_cmd} install azure-cosmos --quiet --break-system-packages && ${var.python_cmd} ${path.module}/init.py"

    environment = {
      COSMOS_ENDPOINT = azurerm_cosmosdb_account.main.endpoint
      COSMOS_KEY      = azurerm_cosmosdb_account.main.primary_key
      COSMOS_DATABASE = var.cosmos_db_name
    }
  }

  depends_on = [azurerm_cosmosdb_sql_database.main]
}

# == Service Bus ===============================================================
resource "azurerm_servicebus_namespace" "main" {
  name                          = "${local.p}-sb-${local.env}"
  location                      = azurerm_resource_group.main.location
  resource_group_name           = azurerm_resource_group.main.name
  sku                           = "Standard"
  public_network_access_enabled = true
  tags                          = local.tags
}

resource "azurerm_servicebus_queue" "leads" {
  name         = "leads"
  namespace_id = azurerm_servicebus_namespace.main.id

  max_size_in_megabytes                = 1024
  default_message_ttl                  = "P14D"
  lock_duration                        = "PT1M"
  dead_lettering_on_message_expiration = true
}

# Kept for local dev/fallback; managed identity is used in Azure
resource "azurerm_servicebus_namespace_authorization_rule" "apps" {
  name         = "apps-send-listen"
  namespace_id = azurerm_servicebus_namespace.main.id
  listen       = true
  send         = true
  manage       = false
}

# == Key Vault =================================================================
resource "azurerm_key_vault" "main" {
  name                          = local.kv_name
  location                      = azurerm_resource_group.main.location
  resource_group_name           = azurerm_resource_group.main.name
  tenant_id                     = data.azurerm_client_config.current.tenant_id
  sku_name                      = "standard"
  soft_delete_retention_days    = 90
  purge_protection_enabled      = false // true in handoff; disable purge protection since we want to allow terraform to fully clean up
  rbac_authorization_enabled    = true
  public_network_access_enabled = true

  network_acls {
    default_action = "Allow"
    bypass         = "AzureServices"
  }

  tags = local.tags
}

# Allow Terraform caller to manage secrets
resource "azurerm_role_assignment" "terraform_kv" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_role_assignment" "backend_kv" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_function_app.backend.identity[0].principal_id
}

resource "azurerm_role_assignment" "email_kv" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_function_app.email.identity[0].principal_id
}

# == Key Vault secrets =========================================================

# Gmail credentials; provided via vars, never stored in state plaintext
resource "azurerm_key_vault_secret" "gmail_user" {
  name         = "GMAIL-USER"
  value        = var.gmail_user
  key_vault_id = azurerm_key_vault.main.id
  tags         = local.tags
  depends_on   = [azurerm_role_assignment.terraform_kv]
  content_type = "text/plain"
}

resource "azurerm_key_vault_secret" "gmail_app_password" {
  name         = "GMAIL-APP-PASSWORD"
  value        = var.gmail_app_password
  key_vault_id = azurerm_key_vault.main.id
  tags         = local.tags
  depends_on   = [azurerm_role_assignment.terraform_kv]
  content_type = "text/plain"
}

# Foundry key & endpoint auto-populated from provisioned resource; no manual copy needed
resource "azurerm_key_vault_secret" "openai_api_key" {
  name         = "OPENAI-API-KEY"
  value        = azurerm_cognitive_account.foundry.primary_access_key
  key_vault_id = azurerm_key_vault.main.id
  tags         = local.tags
  depends_on   = [azurerm_role_assignment.terraform_kv]
  content_type = "text/plain"
}

resource "azurerm_key_vault_secret" "openai_base_url" {
  name         = "OPENAI-BASE-URL"
  value        = "${azurerm_cognitive_account.foundry.endpoint}openai/v1/"
  key_vault_id = azurerm_key_vault.main.id
  tags         = local.tags
  depends_on   = [azurerm_role_assignment.terraform_kv]
  content_type = "text/plain"
}

# == Microsoft Foundry =======================================================
resource "azurerm_cognitive_account" "foundry" {
  name                = "${local.p}-foundry-${local.env}"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  kind                = "AIServices"
  sku_name            = "S0"

  custom_subdomain_name      = "${local.p}-foundry-${local.env}"
  project_management_enabled = true

  public_network_access_enabled = true

  identity {
    type = "SystemAssigned"
  }

  tags = local.tags
}

resource "azurerm_cognitive_account_project" "main" {
  name                 = "${local.p}-foundry-project-${local.env}"
  location             = var.location
  cognitive_account_id = azurerm_cognitive_account.foundry.id

  identity {
    type = "SystemAssigned"
  }

  tags = local.tags
}

resource "azurerm_cognitive_deployment" "gpt" {
  name                 = var.foundry_model_name
  cognitive_account_id = azurerm_cognitive_account.foundry.id

  model {
    format  = "OpenAI"
    name    = var.foundry_model_name
    version = var.foundry_model_version
  }

  sku {
    name     = "GlobalStandard"
    capacity = 10
  }
}

# == Managed Identity RBAC assignments =========================================

# Cosmos DB; built-in data contributor role
resource "azurerm_cosmosdb_sql_role_assignment" "backend" {
  resource_group_name = azurerm_resource_group.main.name
  account_name        = azurerm_cosmosdb_account.main.name
  role_definition_id  = "${azurerm_cosmosdb_account.main.id}/sqlRoleDefinitions/00000000-0000-0000-0000-000000000002"
  principal_id        = azurerm_linux_function_app.backend.identity[0].principal_id
  scope               = azurerm_cosmosdb_account.main.id
}

resource "azurerm_cosmosdb_sql_role_assignment" "email" {
  resource_group_name = azurerm_resource_group.main.name
  account_name        = azurerm_cosmosdb_account.main.name
  role_definition_id  = "${azurerm_cosmosdb_account.main.id}/sqlRoleDefinitions/00000000-0000-0000-0000-000000000002"
  principal_id        = azurerm_linux_function_app.email.identity[0].principal_id
  scope               = azurerm_cosmosdb_account.main.id
}

# Service Bus; sender for backend, receiver for email
resource "azurerm_role_assignment" "backend_sb_sender" {
  scope                = azurerm_servicebus_queue.leads.id
  role_definition_name = "Azure Service Bus Data Sender"
  principal_id         = azurerm_linux_function_app.backend.identity[0].principal_id
}

resource "azurerm_role_assignment" "email_sb_receiver" {
  scope                = azurerm_servicebus_queue.leads.id
  role_definition_name = "Azure Service Bus Data Receiver"
  principal_id         = azurerm_linux_function_app.email.identity[0].principal_id
}

locals {
  storage_roles = toset([
    "Storage Blob Data Contributor",
    "Storage Queue Data Contributor",
    "Storage Table Data Contributor",
  ])
}

resource "azurerm_role_assignment" "backend_storage" {
  for_each             = local.storage_roles
  scope                = azurerm_storage_account.main.id
  role_definition_name = each.value
  principal_id         = azurerm_linux_function_app.backend.identity[0].principal_id
}

resource "azurerm_role_assignment" "email_storage" {
  for_each             = local.storage_roles
  scope                = azurerm_storage_account.main.id
  role_definition_name = each.value
  principal_id         = azurerm_linux_function_app.email.identity[0].principal_id
}

# == App Insights ==============================================================
resource "azurerm_log_analytics_workspace" "main" {
  name                = "${local.p}-law-${local.env}"
  location            = azurerm_resource_group.func.location
  resource_group_name = azurerm_resource_group.func.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = local.tags
}

resource "azurerm_application_insights" "backend" {
  name                = "${local.p}-ai-backend-${local.env}"
  location            = azurerm_resource_group.func.location
  resource_group_name = azurerm_resource_group.func.name
  workspace_id        = azurerm_log_analytics_workspace.main.id
  application_type    = "web"
  tags                = local.tags
}

resource "azurerm_application_insights" "email" {
  name                = "${local.p}-ai-email-${local.env}"
  location            = azurerm_resource_group.func.location
  resource_group_name = azurerm_resource_group.func.name
  workspace_id        = azurerm_log_analytics_workspace.main.id
  application_type    = "web"
  tags                = local.tags
}

# == Static Web App (Frontend) ===============================================
resource "azurerm_static_web_app" "frontend" {
  name                = "${local.p}-frontend-${local.env}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku_tier            = "Free"
  sku_size            = "Free"

  tags = local.tags
}

# == App Service Plan (Functions; Consumption) =================================
resource "azurerm_service_plan" "main" {
  name                = "${local.p}-plan-${local.env}"
  location            = azurerm_resource_group.func.location
  resource_group_name = azurerm_resource_group.func.name
  os_type             = "Linux"
  sku_name            = "Y1"
  tags                = local.tags
}

# == Backend; Function App =====================================================
resource "azurerm_linux_function_app" "backend" {
  name                       = "${local.p}-backend-${local.env}"
  location                   = azurerm_resource_group.func.location
  resource_group_name        = azurerm_resource_group.func.name
  service_plan_id            = azurerm_service_plan.main.id
  storage_account_name       = azurerm_storage_account.main.name
  storage_account_access_key = azurerm_storage_account.main.primary_access_key
  https_only                 = true

  identity { type = "SystemAssigned" }

  site_config {
    always_on           = false
    ftps_state          = "Disabled"
    http2_enabled       = true
    minimum_tls_version = "1.2"

    application_stack {
      python_version = "3.12"
    }

    cors {
      allowed_origins = [
        "https://${azurerm_static_web_app.frontend.default_host_name}",
        "http://localhost:8080",
      ]
    }
  }

  app_settings = {
    FUNCTIONS_WORKER_RUNTIME       = "python"
    SCM_DO_BUILD_DURING_DEPLOYMENT = "true"
    CORS_ORIGIN                    = "https://${azurerm_static_web_app.frontend.default_host_name}"

    APPINSIGHTS_INSTRUMENTATIONKEY        = azurerm_application_insights.backend.instrumentation_key
    APPLICATIONINSIGHTS_CONNECTION_STRING = azurerm_application_insights.backend.connection_string

    # Cosmos; endpoint only, managed identity handles auth
    COSMOS_ENDPOINT   = azurerm_cosmosdb_account.main.endpoint
    COSMOS_DB_NAME    = var.cosmos_db_name
    COSMOS_VERIFY_SSL = "true"

    # Service Bus; namespace hostname only, managed identity handles auth
    SB_NAMESPACE = "${azurerm_servicebus_namespace.main.name}.servicebus.windows.net"

    # Storage account name surfaced to app code; auth via managed identity
    STORAGE_ACCOUNT_NAME = azurerm_storage_account.main.name
  }

  tags       = local.tags
  depends_on = [azurerm_role_assignment.terraform_kv]
}

# == Email Processing; Durable Function App ====================================
resource "azurerm_linux_function_app" "email" {
  name                       = "${local.p}-email-${local.env}"
  location                   = azurerm_resource_group.func.location
  resource_group_name        = azurerm_resource_group.func.name
  service_plan_id            = azurerm_service_plan.main.id
  storage_account_name       = azurerm_storage_account.main.name
  storage_account_access_key = azurerm_storage_account.main.primary_access_key
  https_only                 = true

  identity { type = "SystemAssigned" }

  site_config {
    always_on           = false
    ftps_state          = "Disabled"
    http2_enabled       = true
    minimum_tls_version = "1.2"

    application_stack {
      python_version = "3.12"
    }
  }

  app_settings = {
    FUNCTIONS_WORKER_RUNTIME       = "python"
    SCM_DO_BUILD_DURING_DEPLOYMENT = "true"

    FOLLOWUP_TIMER          = var.followup_timer
    FOLLOWUP_TIME_STRUCTURE = var.followup_time_structure
    ADMIN_EMAIL             = var.admin_email

    # Service Bus trigger binding; identity auth
    AzureWebJobsServiceBus__fullyQualifiedNamespace = "${azurerm_servicebus_namespace.main.name}.servicebus.windows.net"
    AzureWebJobsServiceBus__credential              = "managedidentity"

    APPINSIGHTS_INSTRUMENTATIONKEY        = azurerm_application_insights.email.instrumentation_key
    APPLICATIONINSIGHTS_CONNECTION_STRING = azurerm_application_insights.email.connection_string

    # Cosmos; endpoint only, managed identity handles auth
    COSMOS_ENDPOINT   = azurerm_cosmosdb_account.main.endpoint
    COSMOS_DB_NAME    = var.cosmos_db_name
    COSMOS_VERIFY_SSL = "true"

    # Service Bus; namespace hostname only, managed identity handles auth
    SB_NAMESPACE = "${azurerm_servicebus_namespace.main.name}.servicebus.windows.net"

    # Storage account name surfaced to app code; auth via managed identity
    STORAGE_ACCOUNT_NAME = azurerm_storage_account.main.name

    # Gmail credentials via KV references
    GMAIL_USER         = "@Microsoft.KeyVault(VaultName=${local.kv_name};SecretName=GMAIL-USER)"
    GMAIL_APP_PASSWORD = "@Microsoft.KeyVault(VaultName=${local.kv_name};SecretName=GMAIL-APP-PASSWORD)"

    # Azure AI Foundry; key + endpoint auto-wired from provisioned resource via KV
    OPENAI_API_KEY    = "@Microsoft.KeyVault(VaultName=${local.kv_name};SecretName=OPENAI-API-KEY)"
    OPENAI_BASE_URL   = "@Microsoft.KeyVault(VaultName=${local.kv_name};SecretName=OPENAI-BASE-URL)"
    OPENAI_MODEL_NAME = var.foundry_model_name
  }

  tags = local.tags
  depends_on = [
    azurerm_role_assignment.terraform_kv,
    azurerm_cognitive_deployment.gpt,
  ]
}

resource "azurerm_monitor_diagnostic_setting" "kv" {
  name                       = "kv-diag"
  target_resource_id         = azurerm_key_vault.main.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  enabled_log {
    category = "AuditEvent"
  }
  metric {
    category = "AllMetrics"
    enabled  = false
  }
}

resource "azurerm_monitor_diagnostic_setting" "servicebus" {
  name                       = "sb-diag"
  target_resource_id         = azurerm_servicebus_namespace.main.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  enabled_log {
    category = "OperationalLogs"
  }
  metric {
    category = "AllMetrics"
    enabled  = false
  }
}

resource "azurerm_monitor_diagnostic_setting" "cosmos" {
  name                       = "cosmos-diag"
  target_resource_id         = azurerm_cosmosdb_account.main.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  enabled_log {
    category = "DataPlaneRequests"
  }
  metric {
    category = "Requests"
    enabled  = false
  }
}