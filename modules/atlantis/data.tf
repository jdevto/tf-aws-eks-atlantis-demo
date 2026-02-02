# Get ALB details
data "aws_lb" "shared_alb_details" {
  count = var.alb_arn != "" ? 1 : 0

  arn = var.alb_arn
}
