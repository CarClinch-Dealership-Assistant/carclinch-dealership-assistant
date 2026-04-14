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

variable "admin_email" {
  type        = string
  description = "Email address to receive admin notifications (e.g. booking appointments, escalations, etc.)"
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

# == Follow-up Timer ===========================================================
variable "followup_time_structure" {
  type        = string
  description = "Time structure for follow-up timer (e.g. 'seconds', 'minutes', 'hours')"
  default     = "hours"
}

variable "followup_timer" {
  type        = string
  description = "Comma-separated time intervals for follow-ups (e.g. '24,24,24' for 3 follow-ups at 24 hours)"
  default     = "24,24,24"
}

# == Local Development Overrides =================================================
variable "python_cmd" {
  description = "Python executable name (python3 on Linux/Mac, python on Windows)"
  type        = string
  default     = "python3"
}

variable "pip_cmd" {
  description = "Pip executable name (pip3 on Linux/Mac, pip on Windows)"
  type        = string
  default     = "pip3"
}
