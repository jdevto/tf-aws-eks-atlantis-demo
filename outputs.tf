# output "cluster_name" {
#   description = "Name of the EKS cluster"
#   value       = module.eks.cluster_name
# }

# output "cluster_endpoint" {
#   description = "Endpoint for EKS control plane"
#   value       = module.eks.cluster_endpoint
# }

# output "argocd_server_url" {
#   description = "ArgoCD server URL"
#   value       = module.argocd.argocd_server_url
# }

# output "argocd_username" {
#   description = "ArgoCD username"
#   value       = module.argocd.argocd_username
# }

# output "argocd_password" {
#   description = "ArgoCD password"
#   value       = module.argocd.argocd_password
# }

# # # # output "argocd_custom_domain" {
# # # #   description = "ArgoCD custom domain"
# # # #   value       = module.route53-argocd.custom_domain
# # # # }

# output "platform_url" {
#   description = "Platform URL with protocol (http:// or https://)"
#   value = var.enable_shared_alb ? (
#     var.enable_https ? "https://${module.landing_page[0].custom_domain}" : "http://${module.landing_page[0].custom_domain}"
#   ) : ""
# }

# # output "shared_alb_dns_name" {
# #   description = "Shared ALB DNS name"
# #   value       = module.eks.shared_alb_dns_name
# # }

# output "shared_alb_arn" {
#   value = module.eks.shared_alb_arn
# }
