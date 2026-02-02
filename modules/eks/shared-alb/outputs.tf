output "alb_arn" {
  value       = var.ingress_group_name != "" && length(try(data.aws_lbs.shared_alb.arns, [])) > 0 ? tolist(data.aws_lbs.shared_alb.arns)[0] : ""
  description = "Shared ALB ARN. Empty until ALB is created by AWS Load Balancer Controller or if enable is false."
}

output "security_group_id" {
  value       = aws_security_group.shared_alb.id
  description = "Security group ID for shared ALB. Always created when enabled to avoid chicken-and-egg problems."
}
