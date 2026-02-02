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
  tags = {
    "elbv2.k8s.aws/cluster" = var.cluster_name
    "ingress.k8s.aws/stack" = var.ingress_group_name
  }
}

locals {
  # Check if we need IP restrictions (when allowed_ips is set and doesn't allow all)
  # If allowed_ips is empty or contains "0.0.0.0/0", we don't need restrictions
  needs_ip_restrictions = length(var.allowed_ips) > 0 && !contains(var.allowed_ips, "0.0.0.0/0")

  # Merge VPC CIDR with allowed IPs for restrictive rules
  # VPC CIDR is always included for internal ALB health checks and internal traffic
  # Remove duplicates in case user already included VPC CIDR in their allowed IPs
  allowed_cidrs = local.needs_ip_restrictions ? distinct(concat(
    [data.aws_vpc.this.cidr_block],
    var.allowed_ips
  )) : []
}

# =============================================================================
# Security Group for Shared ALB
# Always created when enabled to avoid chicken-and-egg problem
# IP restrictions are applied only when needed (allowed_ips is set and doesn't allow all)
# =============================================================================

resource "aws_security_group" "shared_alb" {
  name        = "${var.name}-shared-alb"
  description = local.needs_ip_restrictions ? "Security group for shared ALB with IP restrictions" : "Security group for shared ALB"
  vpc_id      = var.vpc_id

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-shared-alb"
    }
  )
}

# Allow HTTP - either restricted to allowed IPs or open to all
resource "aws_security_group_rule" "shared_alb_http_ingress" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = local.needs_ip_restrictions ? local.allowed_cidrs : ["0.0.0.0/0"]
  security_group_id = aws_security_group.shared_alb.id
  description       = local.needs_ip_restrictions ? "Allow HTTP from VPC CIDR and allowed IPs" : "Allow HTTP from all IPs"
}

# Allow HTTPS - either restricted to allowed IPs or open to all
resource "aws_security_group_rule" "shared_alb_https_ingress" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = local.needs_ip_restrictions ? local.allowed_cidrs : ["0.0.0.0/0"]
  security_group_id = aws_security_group.shared_alb.id
  description       = local.needs_ip_restrictions ? "Allow HTTPS from VPC CIDR and allowed IPs" : "Allow HTTPS from all IPs"
}

# Allow HTTPS from GitHub webhook IPs (required for GitHub webhooks to reach /atlantis/events)
# These IPs are specifically for GitHub webhook deliveries only
# Source: https://api.github.com/meta (hooks section)
# Only added when IP restrictions are needed (otherwise default security group allows all)
resource "aws_security_group_rule" "shared_alb_https_github_webhooks" {
  count = local.needs_ip_restrictions ? 1 : 0

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
  security_group_id = aws_security_group.shared_alb.id
  description       = "Allow HTTPS from GitHub webhook IPs (required for /atlantis/events endpoint)"
}

# Allow all outbound traffic (for health checks and backend communication)
# Always created when security group exists
resource "aws_security_group_rule" "shared_alb_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 65535
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.shared_alb.id
  description       = "Allow all outbound traffic"
}

# =============================================================================
# Allow ALB to reach EKS pods (required for target-type=ip)
# =============================================================================
# When using target-type=ip, the ALB needs to reach pod IPs directly
# This requires the cluster/node security group to allow traffic from the ALB

# Get the cluster security group ID
data "aws_eks_cluster" "this" {
  name = var.cluster_name
}

# Allow ALB security group to reach pods on HTTP (port 80)
# Always created when security group exists (needed for ALB to reach pods)
resource "aws_security_group_rule" "cluster_allow_alb_http" {
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.shared_alb.id
  security_group_id        = data.aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
  description              = "Allow ALB to reach pods on port 80 for health checks and traffic"
}

# Allow ALB security group to reach pods on HTTPS (port 443)
# Always created when security group exists (needed for ALB to reach pods)
resource "aws_security_group_rule" "cluster_allow_alb_https" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.shared_alb.id
  security_group_id        = data.aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
  description              = "Allow ALB to reach pods on port 443 for HTTPS traffic"
}

# Allow ALB security group to reach pods on port 8080 (used by ArgoCD and other services)
# Always created when security group exists (needed for ALB to reach pods)
resource "aws_security_group_rule" "cluster_allow_alb_8080" {
  type                     = "ingress"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.shared_alb.id
  security_group_id        = data.aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
  description              = "Allow ALB to reach pods on port 8080 (ArgoCD and other services)"
}

# Allow ALB security group to reach pods on port 4141 (used by Atlantis)
resource "aws_security_group_rule" "cluster_allow_alb_4141" {
  type                     = "ingress"
  from_port                = 4141
  to_port                  = 4141
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.shared_alb.id
  security_group_id        = data.aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
  description              = "Allow ALB to reach pods on port 4141 (Atlantis)"
}

# Create the ALB by creating an Ingress
resource "kubernetes_ingress_v1" "alb" {
  count = var.ingress_group_name != "" ? 1 : 0

  metadata {
    name      = var.ingress_group_name
    namespace = "kube-system"
    annotations = {
      "alb.ingress.kubernetes.io/scheme"          = "internet-facing"
      "alb.ingress.kubernetes.io/target-type"     = "ip"
      "alb.ingress.kubernetes.io/subnets"         = join(",", var.subnet_ids)
      "alb.ingress.kubernetes.io/group.name"      = var.ingress_group_name
      "alb.ingress.kubernetes.io/security-groups" = aws_security_group.shared_alb.id
      "alb.ingress.kubernetes.io/listen-ports"    = "[{\"HTTP\": 80}]"
    }
  }

  spec {
    ingress_class_name = "alb"
    rule {
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "kubernetes"
              port {
                number = 443
              }
            }
          }
        }
      }
    }
  }
}
