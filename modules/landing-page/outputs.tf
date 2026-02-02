output "custom_domain" {
  description = "Custom domain FQDN for the landing page. Empty if Route53 is not configured."
  value       = try(module.route53[0].custom_domain, "")
}
