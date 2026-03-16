# == Core ======================================================================
variable "prefix" {
  type        = string
  description = "Short prefix used in all resource names"
}

variable "environment" {
  type        = string
  description = "Deployment environment (dev, staging, prod)"
  default     = "dev"
}

variable "location" {
  type        = string
  description = "Primary Azure region for all resources"
  default     = "canadacentral"
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

# == Frontend ==================================================================
variable "frontend_image" {
  type        = string
  description = "Docker image for the frontend"
  default     = "carclinchda/form-frontend-service:latest"
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
  description = "Gmail address used by the email function (e.g. yourapp@gmail.com)"
}

variable "gmail_app_password" {
  type        = string
  sensitive   = true
  description = "Gmail App Password (not your account password; generate one at myaccount.google.com/apppasswords)"
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

# == GitHub =====================================================================
variable "github_token" {
  type        = string
  sensitive   = true
  description = "GitHub PAT with repo and workflow scopes"
}

