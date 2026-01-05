# output "cluster_name" {
#   description = "Name of the EKS cluster"
#   value       = module.eks.cluster_name
# }

# output "cluster_endpoint" {
#   description = "Endpoint for EKS control plane"
#   value       = module.eks.cluster_endpoint
# }

output "argocd_server_url" {
  description = "ArgoCD server URL"
  value       = module.argocd.argocd_server_url
}

output "argocd_username" {
  description = "ArgoCD username"
  value       = module.argocd.argocd_username
}

output "argocd_password" {
  description = "ArgoCD password"
  value       = module.argocd.argocd_password
}
