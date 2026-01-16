output "operator_namespace" {
  description = "Namespace where the Bitwarden Secrets Manager Operator is installed"
  value       = var.enable ? kubernetes_namespace.operator[0].metadata[0].name : null
}

output "secrets_namespace" {
  description = "Namespace for Bitwarden secrets"
  value       = var.enable ? kubernetes_namespace.secrets[0].metadata[0].name : null
}

output "auth_secret_name" {
  description = "Name of the Kubernetes secret containing the Bitwarden access token"
  value       = var.enable && var.access_token != null ? kubernetes_secret.auth_token[0].metadata[0].name : null
}

output "operator_installed" {
  description = "Whether the Bitwarden Secrets Manager Operator is installed"
  value       = var.enable
}
