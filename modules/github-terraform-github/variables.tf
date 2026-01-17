variable "repository_name" {
  description = "Name of the GitHub repository"
  type        = string
}

variable "atlantis_url" {
  description = "URL of the Atlantis instance (for webhook)"
  type        = string
}

variable "state_bucket_name" {
  description = "Name of the S3 bucket for Terraform state backend (backend configuration, not provider-specific)"
  type        = string
}

variable "region" {
  description = "AWS region for S3 backend configuration (backend configuration, not provider-specific)"
  type        = string
}

variable "github_owner" {
  description = "GitHub organization or username"
  type        = string
}

variable "github_app_id" {
  description = "GitHub App ID to install on the organization"
  type        = number
}

variable "github_app_private_key" {
  description = "GitHub App private key (PEM format) for creating PRs via workflow"
  type        = string
  sensitive   = true
}

variable "github_webhook_secret" {
  description = "GitHub webhook secret for Atlantis (used to verify webhook payloads)"
  type        = string
  sensitive   = true
}
