variable "prefix" {
  description = "Short prefix for all resource names, e.g. 'cc'. Set via -var or TF_VAR_prefix."
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9]{2,10}$", var.prefix))
    error_message = "Prefix must be 2-10 lowercase alphanumeric characters."
  }
}

variable "environment" {
  description = "Environment label used in resource names and tags."
  type        = string
  default     = "dev"
}

variable "location" {
  description = "Azure region for all resources."
  type        = string
  default     = "canadacentral"
}

# ── Docker images ─────────────────────────────────────────────────────────────
variable "frontend_image" {
  description = "DockerHub image for the frontend App Service (HTML/CSS/JS)."
  type        = string
  default     = "carclinchda/form-frontend-service:sprint1"
}

variable "backend_image" {
  description = "DockerHub image for the backend Azure Function (Python 3.12)."
  type        = string
  default     = "carclinchda/form-backend-service:sprint1"
}

variable "email_image" {
  description = "DockerHub image for the email-processing Durable Function (Python 3.12)."
  type        = string
  default     = "carclinchda/email-processing-service:sprint1"
}

# ── App config ────────────────────────────────────────────────────────────────
variable "cosmos_database" {
  description = "Cosmos DB SQL database name."
  type        = string
  default     = "CarClinchDB"
}

variable "tags" {
  description = "Extra tags merged onto every resource."
  type        = map(string)
  default     = {}
}

variable "terraform_client_ip" {
  description = "Your local public IP so Terraform can write secrets to Key Vault. Find it at https://ifconfig.me"
  type        = string
}