output "custom_domain" {
  description = "Custom domain FQDN for the landing page"
  value       = module.route53.custom_domain
}
