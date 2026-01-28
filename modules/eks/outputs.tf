# Re-export outputs from the external module
output "cluster_name" {
  value       = module.eks.cluster_name
  description = "Name of the EKS cluster"
}

output "cluster_endpoint" {
  value       = module.eks.cluster_endpoint
  description = "Endpoint for EKS control plane"
}

output "cluster_ca_data" {
  value       = module.eks.cluster_ca_data
  description = "Base64 encoded certificate data required to communicate with the cluster"
}

output "aws_lb_controller_role_arn" {
  value       = module.eks.aws_lb_controller_role_arn
  description = "IAM role ARN for AWS Load Balancer Controller"
}

output "oidc_provider_arn" {
  value       = module.eks.oidc_provider_arn
  description = "ARN of the EKS OIDC provider"
}

output "ebs_csi_driver_role_arn" {
  value       = module.eks.ebs_csi_driver_role_arn
  description = "IAM role ARN for EBS CSI Driver"
}

# Shared ALB outputs
output "shared_alb_dns_name" {
  value       = module.shared_alb.dns_name
  description = "Shared ALB DNS name. Empty until ALB is created by AWS Load Balancer Controller or if enable is false."
}

output "shared_alb_zone_id" {
  value       = module.shared_alb.zone_id
  description = "Shared ALB zone ID. Empty until ALB is created by AWS Load Balancer Controller or if enable is false."
}

output "shared_alb_ingress_group_name" {
  value       = module.shared_alb.ingress_group_name
  description = "Name of the ingress group for shared ALB. Empty if enable is false."
}

output "shared_alb_security_group_id" {
  value       = module.shared_alb.security_group_id
  description = "Security group ID for shared ALB with IP restrictions. Empty if IP restrictions are not configured."
}

output "shared_alb_enable" {
  value       = module.shared_alb.enable
  description = "Whether shared ALB functionality is enabled"
}
