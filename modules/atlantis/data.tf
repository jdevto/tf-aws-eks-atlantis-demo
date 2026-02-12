# Get ALB details. Count uses create_route53 (static) so plan can succeed; precondition ensures alb_arn is set at apply.
data "aws_lb" "shared_alb_details" {
  count = var.create_route53 ? 1 : 0

  arn = var.alb_arn

  lifecycle {
    precondition {
      condition     = !var.create_route53 || var.alb_arn != ""
      error_message = "When create_route53 is true, alb_arn must be set. Run: terraform apply -target=module.shared_alb (ensure AWS LB controller is installed so ALB exists), then terraform apply again."
    }
  }
}
