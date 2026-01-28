# Route53 record for Atlantis
module "route53" {
  source = "../route53"

  name         = var.route53_name
  domain_name  = var.domain_name
  alb_dns_name = var.alb_dns_name
  alb_zone_id  = var.alb_zone_id

  depends_on = [
    kubectl_manifest.atlantis_ingress
  ]
}
