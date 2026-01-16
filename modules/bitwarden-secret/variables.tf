variable "name" {
  description = "Name of the BitwardenSecret CRD and the Kubernetes secret that will be created"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace for the secret"
  type        = string
}

variable "organization_id" {
  description = "Bitwarden organization ID"
  type        = string
}

variable "secret_id" {
  description = "Bitwarden secret ID to sync"
  type        = string
}

variable "key_name" {
  description = "Kubernetes secret key name to store the secret value. If not provided, defaults to the secret name."
  type        = string
  default     = null
}

variable "access_token_secret_name" {
  description = "Name of the Kubernetes secret containing the Bitwarden access token"
  type        = string
  default     = "bitwarden-auth-token"
}

variable "access_token_secret_key" {
  description = "Key name in the access token secret"
  type        = string
  default     = "token"
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
