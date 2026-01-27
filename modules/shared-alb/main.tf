# =============================================================================
# SHARED ALB MODULE
# =============================================================================
# Manages shared ALB functionality for multiple services
# Handles ALB discovery, security groups, and IP restrictions

# Get current AWS region
data "aws_region" "current" {}

# Get VPC CIDR for health check rules
data "aws_vpc" "this" {
  id = var.vpc_id
}

# Get the shared ALB created by AWS Load Balancer Controller
data "aws_lbs" "shared_alb" {
  count = var.enable && var.ingress_group_name != "" ? 1 : 0

  tags = {
    "elbv2.k8s.aws/cluster" = var.cluster_name
    "ingress.k8s.aws/stack" = var.ingress_group_name
  }
}

locals {
  # Merge VPC CIDR with allowed IPs
  # VPC CIDR is always included for internal ALB health checks and internal traffic
  # Remove duplicates in case user already included VPC CIDR in their allowed IPs
  allowed_cidrs = var.enable && length(var.allowed_ips) > 0 ? distinct(concat(
    [data.aws_vpc.this.cidr_block],
    var.allowed_ips
  )) : []

  # Get the first ALB ARN from the list, ensuring we have at least one
  # Convert set to list and get first element
  shared_alb_arn = var.enable && var.ingress_group_name != "" && length(try(data.aws_lbs.shared_alb[0].arns, [])) > 0 ? tolist(data.aws_lbs.shared_alb[0].arns)[0] : null
}

# Get ALB details - query by ARN for precise lookup
# Only create if we have a valid ARN
data "aws_lb" "shared_alb_details" {
  count = local.shared_alb_arn != null ? 1 : 0

  # Use ARN for precise lookup - this should return exactly one result
  arn = local.shared_alb_arn

  depends_on = [
    data.aws_lbs.shared_alb
  ]
}

# =============================================================================
# Security Group for Shared ALB
# Restricts access to allowed IPs when allowed_ips is configured
# =============================================================================

resource "aws_security_group" "shared_alb" {
  count = var.enable && length(var.allowed_ips) > 0 ? 1 : 0

  name        = "${var.name}-shared-alb"
  description = "Security group for shared ALB with IP restrictions"
  vpc_id      = var.vpc_id

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-shared-alb"
    }
  )
}

# Allow HTTP from VPC CIDR + allowed IPs
resource "aws_security_group_rule" "shared_alb_http_ingress" {
  count = var.enable && length(var.allowed_ips) > 0 ? 1 : 0

  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = local.allowed_cidrs
  security_group_id = aws_security_group.shared_alb[0].id
  description       = "Allow HTTP from VPC CIDR and allowed IPs"
}

# Allow HTTPS from VPC CIDR + allowed IPs
resource "aws_security_group_rule" "shared_alb_https_ingress" {
  count = var.enable && length(var.allowed_ips) > 0 ? 1 : 0

  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = local.allowed_cidrs
  security_group_id = aws_security_group.shared_alb[0].id
  description       = "Allow HTTPS from VPC CIDR and allowed IPs"
}

# Allow HTTPS from GitHub webhook IPs (required for GitHub webhooks to reach /atlantis/events)
# These IPs are specifically for GitHub webhook deliveries only
# Source: https://api.github.com/meta (hooks section)
resource "aws_security_group_rule" "shared_alb_https_github_webhooks" {
  count = var.enable && length(var.allowed_ips) > 0 ? 1 : 0

  type      = "ingress"
  from_port = 443
  to_port   = 443
  protocol  = "tcp"
  cidr_blocks = [
    "140.82.112.0/20",  # GitHub webhooks
    "143.55.64.0/20",   # GitHub webhooks
    "185.199.108.0/22", # GitHub webhooks
    "192.30.252.0/22",  # GitHub webhooks
  ]
  security_group_id = aws_security_group.shared_alb[0].id
  description       = "Allow HTTPS from GitHub webhook IPs (required for /atlantis/events endpoint)"
}

# Allow all outbound traffic (for health checks and backend communication)
resource "aws_security_group_rule" "shared_alb_egress" {
  count = var.enable && length(var.allowed_ips) > 0 ? 1 : 0

  type              = "egress"
  from_port         = 0
  to_port           = 65535
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.shared_alb[0].id
  description       = "Allow all outbound traffic"
}
