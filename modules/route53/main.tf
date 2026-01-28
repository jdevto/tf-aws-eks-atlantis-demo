# Get Route53 hosted zone
data "aws_route53_zone" "this" {
  name         = var.domain_name
  private_zone = false
}

# Route53 record pointing to ALB
# Only create when we have valid ALB values (non-empty strings)
# This prevents errors during destroy when ALB is already gone
resource "aws_route53_record" "this" {
  # Only create if domain_name is provided AND we have valid ALB values
  # Check for non-empty strings to avoid validation errors
  count = var.domain_name != "" && var.alb_dns_name != "" && var.alb_zone_id != "" ? 1 : 0

  zone_id = data.aws_route53_zone.this.zone_id
  name    = "${var.name}.${var.domain_name}"
  type    = "A"

  alias {
    # These values are guaranteed to be non-empty due to count condition
    name                   = var.alb_dns_name
    zone_id                = var.alb_zone_id
    evaluate_target_health = true
  }
}
