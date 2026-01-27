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
