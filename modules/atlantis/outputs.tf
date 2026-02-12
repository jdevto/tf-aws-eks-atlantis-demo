output "iam_role_arn" {
  description = "ARN of the IAM role for Atlantis service account"
  value       = aws_iam_role.atlantis.arn
}

output "custom_domain" {
  description = "Custom domain FQDN for Atlantis"
  value       = var.create_route53 ? module.route53[0].custom_domain : ""
}
