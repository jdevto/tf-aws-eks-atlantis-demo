# Get Route53 hosted zone
data "aws_route53_zone" "this" {
  name         = var.domain_name
  private_zone = false
}

# Route53 record pointing to ALB
# Note: ALB DNS name and zone ID may be unknown at plan time (empty string initially)
# Terraform allows unknown values in resource attributes, so we always create the record
# The alias will be populated once the ALB is created by AWS Load Balancer Controller
resource "aws_route53_record" "this" {
  # Always create if domain_name is provided (static condition)
  # The ALB values can be empty/unknown initially - Terraform handles this gracefully
  count = var.domain_name != "" ? 1 : 0

  zone_id = data.aws_route53_zone.this.zone_id
  name    = "${var.name}.${var.domain_name}"
  type    = "A"

  alias {
    # These values may be empty/unknown at plan time, which is OK
    # Terraform will create/update the record once the ALB exists
    # If empty, the record creation will wait until ALB values are available
    name                   = var.alb_dns_name
    zone_id                = var.alb_zone_id
    evaluate_target_health = true
  }
}
