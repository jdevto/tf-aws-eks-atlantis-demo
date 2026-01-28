output "name" {
  description = "Name of the BitwardenSecret CRD"
  value       = var.name
}

output "kubernetes_secret_name" {
  description = "Name of the Kubernetes secret created"
  value       = var.name
}

output "namespace" {
  description = "Namespace where the secret is created"
  value       = var.namespace
}
