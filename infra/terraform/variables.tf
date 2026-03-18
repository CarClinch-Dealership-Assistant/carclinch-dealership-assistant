# == Core ======================================================================
variable "prefix" {
  type        = string
  description = "Short prefix used in all resource names"

  validation {
    condition     = length(var.prefix) <= 6
    error_message = "prefix must be 6 characters or fewer to stay within Azure storage account name limits."
  }
}

variable "environment" {
  type        = string
  description = "Deployment environment (dev, staging, prod)"
  default     = "dev"
}

variable "location" {
  type        = string
  description = "Primary Azure region for all resources"
  default     = "eastus2"
}

variable "tags" {
  type        = map(string)
  description = "Extra tags to merge onto all resources"
  default     = {}
}

# == Network ===================================================================
variable "terraform_client_ip" {
  type        = string
  description = "Your public IP; added to Cosmos DB IP allowlist so Terraform can seed data. Find it at https://ifconfig.me"
}

# == Cosmos DB =================================================================
variable "cosmos_db_name" {
  type        = string
  description = "Cosmos DB database name"
  default     = "CarClinchDB"
}

# == Gmail =====================================================================
variable "gmail_user" {
  type        = string
  sensitive   = true
  description = "Gmail address used by the email function (e.g. yourapp@gmail.com)"
}

variable "gmail_app_password" {
  type        = string
  sensitive   = true
  description = "Gmail App Password (not your account password — generate one at myaccount.google.com/apppasswords)"
}

# == Azure AI Foundry ==========================================================
variable "foundry_model_name" {
  type        = string
  description = "Model deployment name and model name (e.g. gpt-4.1-mini)"
  default     = "gpt-4.1-mini"
}

variable "foundry_model_version" {
  type        = string
  description = "Model version to deploy"
  default     = "2025-04-14"
}

# == GitHub ====================================================================
variable "github_token" {
  type        = string
  sensitive   = true
  description = "GitHub personal access token with repo secrets write permission"
}
