output "operator_namespace" {
  description = "Namespace where the Bitwarden Secrets Manager Operator is installed"
  value       = kubernetes_namespace.operator.metadata[0].name
}

output "secrets_namespace" {
  description = "Namespace for Bitwarden secrets"
  value       = kubernetes_namespace.secrets.metadata[0].name
}

output "auth_secret_name" {
  description = "Name of the Kubernetes secret containing the Bitwarden access token"
  value       = var.access_token != null ? kubernetes_secret.auth_token[0].metadata[0].name : null
}
