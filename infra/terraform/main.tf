terraform {
  required_version = ">= 1.6"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.110"
    }
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
  }
}

data "azurerm_client_config" "current" {}

# ── Locals: naming + tags ─────────────────────────────────────────────────────
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

# ── Resource Group ────────────────────────────────────────────────────────────
resource "azurerm_resource_group" "main" {
  name     = "${local.p}-rg-${local.env}"
  location = local.loc
  tags     = local.tags
}

# ── Storage (required by Azure Functions) ────────────────────────────────────
resource "azurerm_storage_account" "main" {
  name                            = local.storage_name
  resource_group_name             = azurerm_resource_group.main.name
  location                        = azurerm_resource_group.main.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  https_traffic_only_enabled      = true
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  public_network_access_enabled   = true

  # Allow Azure services (Functions runtime) + Terraform client IP
  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"]
    ip_rules       = [var.terraform_client_ip]
  }

  tags = local.tags
}

# ── Azure Communication Services ──────────────────────────────────────────────
# Terraform provisions ACS and extracts the connection string automatically.
resource "azurerm_communication_service" "main" {
  name                = "${local.p}-acs-${local.env}"
  resource_group_name = azurerm_resource_group.main.name
  data_location       = "Canada"
  tags                = local.tags
}

resource "azurerm_email_communication_service" "main" {
  name                = "${local.p}-acs-email-${local.env}"
  resource_group_name = azurerm_resource_group.main.name
  data_location       = "Canada"
  tags                = local.tags
}

# Azure-managed domain — no DNS setup required, ready to send immediately
resource "azurerm_email_communication_service_domain" "azure" {
  name              = "AzureManagedDomain"
  email_service_id  = azurerm_email_communication_service.main.id
  domain_management = "AzureManaged"
  tags              = local.tags
}

# Link the email domain to the communication service
resource "azurerm_communication_service_email_domain_association" "main" {
  communication_service_id = azurerm_communication_service.main.id
  email_service_domain_id  = azurerm_email_communication_service_domain.azure.id
}

# ── Cosmos DB (serverless — no minimum RU charge) ─────────────────────────────
resource "azurerm_cosmosdb_account" "main" {
  name                = "${local.p}-cosmos-${local.env}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"

  # Public access on so Terraform seed script and apps can reach it.
  # ip_range_filter restricts to Azure datacenter IPs + your client IP.
  public_network_access_enabled = true
  ip_range_filter               = "${var.terraform_client_ip},0.0.0.0"

  capabilities { name = "EnableServerless" }

  consistency_policy { consistency_level = "Session" }

  geo_location {
    location          = azurerm_resource_group.main.location
    failover_priority = 0
  }

  tags = local.tags
}

resource "azurerm_cosmosdb_sql_database" "main" {
  name                = var.cosmos_database
  resource_group_name = azurerm_resource_group.main.name
  account_name        = azurerm_cosmosdb_account.main.name
}

# ── Cosmos DB seed ────────────────────────────────────────────────────────────
# Runs init.py from the same directory once after the database is provisioned.
# Trigger is the Cosmos endpoint — only re-runs if the account is replaced.
# init.py uses upsert_item so re-runs are safe.
resource "null_resource" "cosmos_seed" {
  triggers = {
    cosmos_endpoint = azurerm_cosmosdb_account.main.endpoint
  }

  provisioner "local-exec" {
    command = "pip install azure-cosmos --quiet && python ${path.module}/init.py"

    environment = {
      COSMOS_ENDPOINT = azurerm_cosmosdb_account.main.endpoint
      COSMOS_KEY      = azurerm_cosmosdb_account.main.primary_key
      COSMOS_DATABASE = var.cosmos_database
    }
  }

  depends_on = [azurerm_cosmosdb_sql_database.main]
}

# ── Service Bus (Standard — private endpoints require Premium, use network rules) ─
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

# Least-privilege send+listen rule for apps (no manage)
resource "azurerm_servicebus_namespace_authorization_rule" "apps" {
  name         = "apps-send-listen"
  namespace_id = azurerm_servicebus_namespace.main.id
  listen       = true
  send         = true
  manage       = false
}

# ── Key Vault ─────────────────────────────────────────────────────────────────
resource "azurerm_key_vault" "main" {
  name                          = local.kv_name
  location                      = azurerm_resource_group.main.location
  resource_group_name           = azurerm_resource_group.main.name
  tenant_id                     = data.azurerm_client_config.current.tenant_id
  sku_name                      = "standard"
  soft_delete_retention_days    = 7
  purge_protection_enabled      = false
  public_network_access_enabled = true

  network_acls {
    default_action = "Allow"
    bypass         = "AzureServices"
  }

  tags = local.tags
}

# Allow Terraform caller to manage secrets
resource "azurerm_key_vault_access_policy" "terraform" {
  key_vault_id       = azurerm_key_vault.main.id
  tenant_id          = data.azurerm_client_config.current.tenant_id
  object_id          = data.azurerm_client_config.current.object_id
  secret_permissions = ["Get", "List", "Set", "Delete", "Purge", "Recover"]
}

# Allow app managed identities to read secrets
resource "azurerm_key_vault_access_policy" "frontend" {
  key_vault_id       = azurerm_key_vault.main.id
  tenant_id          = data.azurerm_client_config.current.tenant_id
  object_id          = azurerm_linux_web_app.frontend.identity[0].principal_id
  secret_permissions = ["Get", "List"]
}

resource "azurerm_key_vault_access_policy" "backend" {
  key_vault_id       = azurerm_key_vault.main.id
  tenant_id          = data.azurerm_client_config.current.tenant_id
  object_id          = azurerm_linux_function_app.backend.identity[0].principal_id
  secret_permissions = ["Get", "List"]
}

resource "azurerm_key_vault_access_policy" "email" {
  key_vault_id       = azurerm_key_vault.main.id
  tenant_id          = data.azurerm_client_config.current.tenant_id
  object_id          = azurerm_linux_function_app.email.identity[0].principal_id
  secret_permissions = ["Get", "List"]
}

# ── Key Vault secrets — all sourced from provisioned resources, zero manual input ──
resource "azurerm_key_vault_secret" "acs_connection_string" {
  name         = "ACS-CONNECTION-STRING"
  value        = azurerm_communication_service.main.primary_connection_string
  key_vault_id = azurerm_key_vault.main.id
  tags         = local.tags
  depends_on   = [azurerm_key_vault_access_policy.terraform]
}

resource "azurerm_key_vault_secret" "sender_address" {
  name         = "SENDER-ADDRESS"
  value        = "DoNotReply@${azurerm_email_communication_service_domain.azure.mail_from_sender_domain}"
  key_vault_id = azurerm_key_vault.main.id
  tags         = local.tags
  depends_on   = [azurerm_key_vault_access_policy.terraform]
}

resource "azurerm_key_vault_secret" "sb_connection_string" {
  name         = "SB-CONNECTION-STRING"
  value        = azurerm_servicebus_namespace_authorization_rule.apps.primary_connection_string
  key_vault_id = azurerm_key_vault.main.id
  tags         = local.tags
  depends_on   = [azurerm_key_vault_access_policy.terraform]
}

resource "azurerm_key_vault_secret" "cosmos_connection_string" {
  name         = "COSMOS-CONNECTION-STRING"
  value        = azurerm_cosmosdb_account.main.primary_sql_connection_string
  key_vault_id = azurerm_key_vault.main.id
  tags         = local.tags
  depends_on   = [azurerm_key_vault_access_policy.terraform]
}

resource "azurerm_key_vault_secret" "cosmos_endpoint" {
  name         = "COSMOS-ENDPOINT"
  value        = azurerm_cosmosdb_account.main.endpoint
  key_vault_id = azurerm_key_vault.main.id
  tags         = local.tags
  depends_on   = [azurerm_key_vault_access_policy.terraform]
}

resource "azurerm_key_vault_secret" "cosmos_key" {
  name         = "COSMOS-KEY"
  value        = azurerm_cosmosdb_account.main.primary_key
  key_vault_id = azurerm_key_vault.main.id
  tags         = local.tags
  depends_on   = [azurerm_key_vault_access_policy.terraform]
}

resource "azurerm_key_vault_secret" "cosmos_database" {
  name         = "COSMOS-DATABASE"
  value        = var.cosmos_database
  key_vault_id = azurerm_key_vault.main.id
  tags         = local.tags
  depends_on   = [azurerm_key_vault_access_policy.terraform]
}

resource "azurerm_key_vault_secret" "storage_connection_string" {
  name         = "STORAGE-CONNECTION-STRING"
  value        = azurerm_storage_account.main.primary_connection_string
  key_vault_id = azurerm_key_vault.main.id
  tags         = local.tags
  depends_on   = [azurerm_key_vault_access_policy.terraform]
}

# ── App Insights ──────────────────────────────────────────────────────────────
resource "azurerm_log_analytics_workspace" "main" {
  name                = "${local.p}-law-${local.env}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = local.tags
}

resource "azurerm_application_insights" "backend" {
  name                = "${local.p}-ai-backend-${local.env}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  workspace_id        = azurerm_log_analytics_workspace.main.id
  application_type    = "web"
  tags                = local.tags
}

resource "azurerm_application_insights" "email" {
  name                = "${local.p}-ai-email-${local.env}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  workspace_id        = azurerm_log_analytics_workspace.main.id
  application_type    = "web"
  tags                = local.tags
}

# ── App Service Plan (B1 — cheapest with container support) ──────────────────
resource "azurerm_service_plan" "main" {
  name                = "${local.p}-plan-${local.env}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  os_type             = "Linux"
  sku_name            = "B1"
  tags                = local.tags
}

# ── Frontend — App Service (HTML/CSS/JS container) ────────────────────────────
resource "azurerm_linux_web_app" "frontend" {
  name                = "${local.p}-frontend-${local.env}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  service_plan_id     = azurerm_service_plan.main.id
  https_only          = true

  identity { type = "SystemAssigned" }

  site_config {
    always_on           = false
    ftps_state          = "Disabled"
    http2_enabled       = true
    minimum_tls_version = "1.2"

    application_stack {
      docker_image_name   = var.frontend_image
      docker_registry_url = "https://index.docker.io"
    }
  }

  app_settings = {
    WEBSITES_ENABLE_APP_SERVICE_STORAGE = "false"
    DOCKER_ENABLE_CI                    = "true"
    BACKEND_URL                         = "https://${local.p}-backend-${local.env}.azurewebsites.net/api"
    WEBSITES_PORT                       = "80"
  }

  logs {
    application_logs { file_system_level = "Warning" }
  }

  tags = local.tags
}

# ── Backend — Azure Function App (Python 3.12, HTTP-triggered) ────────────────
resource "azurerm_linux_function_app" "backend" {
  name                       = "${local.p}-backend-${local.env}"
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  service_plan_id            = azurerm_service_plan.main.id
  storage_account_name       = azurerm_storage_account.main.name
  storage_account_access_key = azurerm_storage_account.main.primary_access_key
  https_only                 = true

  identity { type = "SystemAssigned" }

  site_config {
    always_on                               = false
    ftps_state                              = "Disabled"
    http2_enabled                           = true
    minimum_tls_version                     = "1.2"
    container_registry_use_managed_identity = false

    application_stack { use_custom_runtime = true }
  }

  app_settings = {
    FUNCTIONS_WORKER_RUNTIME            = "python"
    WEBSITES_ENABLE_APP_SERVICE_STORAGE = "false"
    DOCKER_ENABLE_CI                    = "true"
    DOCKER_CUSTOM_IMAGE_NAME            = var.backend_image
    DOCKER_REGISTRY_SERVER_URL          = "https://index.docker.io"
    WEBSITES_PORT                       = "80"
    FUNCTIONS_WORKER_RUNTIME_VERSION    = "3.12"
    AZURE_FUNCTIONS_ENVIRONMENT         = "Development"
    APPINSIGHTS_INSTRUMENTATIONKEY        = azurerm_application_insights.backend.instrumentation_key
    APPLICATIONINSIGHTS_CONNECTION_STRING = azurerm_application_insights.backend.connection_string
    ACS_CONNECTION_STRING     = "@Microsoft.KeyVault(VaultName=${local.kv_name};SecretName=ACS-CONNECTION-STRING)"
    SENDER_ADDRESS            = "@Microsoft.KeyVault(VaultName=${local.kv_name};SecretName=SENDER-ADDRESS)"
    SB_CONNECTION_STRING      = "@Microsoft.KeyVault(VaultName=${local.kv_name};SecretName=SB-CONNECTION-STRING)"
    COSMOS_CONNECTION_STRING  = "@Microsoft.KeyVault(VaultName=${local.kv_name};SecretName=COSMOS-CONNECTION-STRING)"
    COSMOS_ENDPOINT           = "@Microsoft.KeyVault(VaultName=${local.kv_name};SecretName=COSMOS-ENDPOINT)"
    COSMOS_KEY                = "@Microsoft.KeyVault(VaultName=${local.kv_name};SecretName=COSMOS-KEY)"
    COSMOS_DATABASE           = var.cosmos_database
    STORAGE_CONNECTION_STRING = "@Microsoft.KeyVault(VaultName=${local.kv_name};SecretName=STORAGE-CONNECTION-STRING)"
  }

  tags       = local.tags
  depends_on = [azurerm_key_vault_access_policy.terraform]
}

# ── Email Processing — Azure Durable Function App (Python 3.12) ───────────────
resource "azurerm_linux_function_app" "email" {
  name                       = "${local.p}-email-${local.env}"
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
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

    application_stack { use_custom_runtime = true }
  }

  app_settings = {
    APPINSIGHTS_INSTRUMENTATIONKEY        = azurerm_application_insights.email.instrumentation_key
    APPLICATIONINSIGHTS_CONNECTION_STRING = azurerm_application_insights.email.connection_string
    FUNCTIONS_WORKER_RUNTIME            = "python"
    WEBSITES_ENABLE_APP_SERVICE_STORAGE = "false"
    DOCKER_ENABLE_CI                    = "true"
    DOCKER_CUSTOM_IMAGE_NAME            = var.email_image
    DOCKER_REGISTRY_SERVER_URL          = "https://index.docker.io"

    # Durable Functions needs storage for orchestration state
    AzureWebJobsStorage = azurerm_storage_account.main.primary_connection_string

    ACS_CONNECTION_STRING     = "@Microsoft.KeyVault(VaultName=${local.kv_name};SecretName=ACS-CONNECTION-STRING)"
    SENDER_ADDRESS            = "@Microsoft.KeyVault(VaultName=${local.kv_name};SecretName=SENDER-ADDRESS)"
    SB_CONNECTION_STRING      = "@Microsoft.KeyVault(VaultName=${local.kv_name};SecretName=SB-CONNECTION-STRING)"
    COSMOS_CONNECTION_STRING  = "@Microsoft.KeyVault(VaultName=${local.kv_name};SecretName=COSMOS-CONNECTION-STRING)"
    COSMOS_ENDPOINT           = "@Microsoft.KeyVault(VaultName=${local.kv_name};SecretName=COSMOS-ENDPOINT)"
    COSMOS_KEY                = "@Microsoft.KeyVault(VaultName=${local.kv_name};SecretName=COSMOS-KEY)"
    COSMOS_DATABASE           = var.cosmos_database
    STORAGE_CONNECTION_STRING = "@Microsoft.KeyVault(VaultName=${local.kv_name};SecretName=STORAGE-CONNECTION-STRING)"
  }

  tags       = local.tags
  depends_on = [azurerm_key_vault_access_policy.terraform]
}
