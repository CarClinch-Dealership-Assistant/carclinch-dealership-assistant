# == Core ======================================================================
variable "prefix" {
  type        = string
  description = "Short prefix used in all resource names (lowercase letters and numbers only)"

  validation {
    # Storage account name = "<prefix>st<env>", truncated to 24 chars by substr().
    # Worst case: prefix(15) + "st"(2) + "staging"(7) = 24 — exactly the Azure limit.
    # Also enforces lowercase alphanumeric — Azure storage rejects anything else.
    condition     = can(regex("^[a-z0-9]{1,15}$", var.prefix))
    error_message = "prefix must be 1-15 lowercase letters/numbers. The storage account name is built as '<prefix>st<env>' (max 24 chars) — Azure requires lowercase alphanumeric only."
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
  default     = ""
  description = "GitHub personal access token with repo secrets write permission. Leave empty to skip GitHub secret injection."
}

# == Email follow-up ===========================================================
variable "followup_timer" {
  type        = string
  description = "Interval between follow-up emails in hours (e.g. 24)"
  default     = "24"
}

variable "followup_time_structure" {
  type        = string
  description = "Durable timer time structure string (e.g. PT24H)"
  default     = "PT24H"
}

# == CI/CD =====================================================================
variable "extra_cosmos_ips" {
  type        = list(string)
  description = "Additional IPs to add to the Cosmos DB firewall (e.g. CI/CD runner public IPs). Pass via TF_VAR_extra_cosmos_ips='[\"1.2.3.4\"]' in your pipeline."
  default     = []
}
