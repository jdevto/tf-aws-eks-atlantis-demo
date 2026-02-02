# Get Route53 hosted zone
# Only query when domain_name is provided
data "aws_route53_zone" "this" {
  count = var.domain_name != "" ? 1 : 0

  name         = var.domain_name
  private_zone = false
}

# Route53 record pointing to ALB
# Only create when domain_name is provided (static condition)
# ALB values (alb_dns_name, alb_zone_id) are computed and will be available at apply time
resource "aws_route53_record" "this" {
  # Only check domain_name in count (static value)
  # ALB values are computed and will be populated at apply time
  count = var.domain_name != "" ? 1 : 0

  zone_id = data.aws_route53_zone.this[0].zone_id
  name    = "${var.name}.${var.domain_name}"
  type    = "A"

  alias {
    # These values are computed from ALB outputs and will be available at apply time
    name                   = var.alb_dns_name
    zone_id                = var.alb_zone_id
    evaluate_target_health = true
  }
}
