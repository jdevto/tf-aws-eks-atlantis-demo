output "enable" {
  value       = var.enable
  description = "Whether shared ALB functionality is enabled"
}

output "dns_name" {
  value = local.shared_alb_arn != null && length(data.aws_lb.shared_alb_details) > 0 ? try(
    data.aws_lb.shared_alb_details[0].dns_name,
    ""
  ) : ""
  description = "Shared ALB DNS name. Empty until ALB is created by AWS Load Balancer Controller or if enable is false."
}

output "zone_id" {
  value = local.shared_alb_arn != null && length(data.aws_lb.shared_alb_details) > 0 ? try(
    data.aws_lb.shared_alb_details[0].zone_id,
    ""
  ) : ""
  description = "Shared ALB zone ID. Empty until ALB is created by AWS Load Balancer Controller or if enable is false."
}

output "ingress_group_name" {
  value       = var.enable ? var.ingress_group_name : ""
  description = "Name of the ingress group for shared ALB. Empty if enable is false."
}

output "security_group_id" {
  value       = var.enable && length(var.allowed_ips) > 0 ? aws_security_group.shared_alb[0].id : ""
  description = "Security group ID for shared ALB with IP restrictions. Empty if IP restrictions are not configured."
}
