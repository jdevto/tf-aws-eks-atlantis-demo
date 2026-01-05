output "cluster_name" {
  value = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  value = aws_eks_cluster.this.endpoint
}

output "cluster_ca_data" {
  value = aws_eks_cluster.this.certificate_authority[0].data
}

output "aws_lb_controller_role_arn" {
  value       = aws_iam_role.aws_lb_controller.arn
  description = "IAM role ARN for AWS Load Balancer Controller"
}

output "oidc_provider_arn" {
  value       = aws_iam_openid_connect_provider.eks.arn
  description = "ARN of the EKS OIDC provider"
}
