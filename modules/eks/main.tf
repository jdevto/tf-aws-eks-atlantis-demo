# Get current AWS region
data "aws_region" "current" {}

# Get VPC CIDR for health check rules
data "aws_vpc" "this" {
  id = var.vpc_id
}

# =============================================================================
# EKS Cluster using external module
# =============================================================================

module "eks" {
  source = "github.com/tfstack/terraform-aws-eks-basic?ref=main"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version
  vpc_id          = var.vpc_id
  subnet_ids      = var.subnet_ids
  node_subnet_ids = var.node_subnet_ids != null ? var.node_subnet_ids : var.subnet_ids

  endpoint_public_access    = var.endpoint_public_access
  public_access_cidrs       = var.public_access_cidrs
  enabled_cluster_log_types = var.enabled_cluster_log_types

  # Node group configuration
  node_instance_types                = var.node_instance_types
  node_desired_size                  = var.node_desired_size
  node_min_size                      = var.node_min_size
  node_max_size                      = var.node_max_size
  node_disk_size                     = var.node_disk_size
  node_update_max_unavailable        = var.node_update_max_unavailable
  node_remote_access_enabled         = var.node_remote_access_enabled
  node_remote_access_ssh_key         = var.node_remote_access_ssh_key
  node_remote_access_security_groups = var.node_remote_access_security_groups
  node_labels                        = var.node_labels

  # AWS Auth ConfigMap
  aws_auth_map_users = var.aws_auth_map_users
  aws_auth_map_roles = var.aws_auth_map_roles

  # Addons
  enable_ebs_csi_driver  = var.enable_ebs_csi_driver
  ebs_csi_driver_version = var.ebs_csi_driver_version

  instance_types = var.node_instance_types

  # Disk size configuration
  disk_size = var.node_disk_size

  scaling_config {
    desired_size = var.node_desired_size
    min_size     = var.node_min_size
    max_size     = var.node_max_size
  }

  # Update configuration for rolling updates
  update_config {
    max_unavailable = var.node_update_max_unavailable
  }

  # Remote access configuration (SSH access control)
  dynamic "remote_access" {
    for_each = var.node_remote_access_enabled ? [1] : []
    content {
      ec2_ssh_key               = var.node_remote_access_ssh_key
      source_security_group_ids = var.node_remote_access_security_groups
    }
  }

  # Node labels (taints should be applied via Kubernetes, not at node group level)
  labels = var.node_labels

  tags = var.tags

  depends_on = [
    aws_iam_role_policy_attachment.eks_nodes_worker,
    aws_iam_role_policy_attachment.eks_nodes_cni,
    aws_iam_role_policy_attachment.eks_nodes_ecr,
  ]
}

# =============================================================================
# AWS Auth ConfigMap
# Maps IAM users and roles to Kubernetes RBAC groups
# Automatically includes the node group role so worker nodes can authenticate
# =============================================================================

locals {
  # Always include the node group role for worker node authentication
  node_group_role = {
    rolearn  = aws_iam_role.eks_nodes.arn
    username = "system:node:{{EC2PrivateDNSName}}"
    groups = [
      "system:bootstrappers",
      "system:nodes"
    ]
  }

  # Combine node group role with user-provided roles
  all_map_roles = concat([local.node_group_role], var.aws_auth_map_roles)
}

resource "kubernetes_config_map_v1" "aws_auth" {
  count = length(var.aws_auth_map_users) > 0 || length(var.aws_auth_map_roles) > 0 ? 1 : 0

  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  data = {
    mapUsers = length(var.aws_auth_map_users) > 0 ? yamlencode(var.aws_auth_map_users) : yamlencode([])
    mapRoles = yamlencode(local.all_map_roles)
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_eks_cluster.this,
    aws_eks_node_group.default
  ]
}

# =============================================================================
# EBS CSI Driver IAM (IRSA setup)
# =============================================================================

# IAM role for EBS CSI Driver
data "aws_iam_policy_document" "ebs_csi_driver_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
    }

    actions = ["sts:AssumeRoleWithWebIdentity"]

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ebs_csi_driver" {
  count = var.enable_ebs_csi_driver ? 1 : 0

  name               = "${var.cluster_name}-ebs-csi-driver"
  assume_role_policy = data.aws_iam_policy_document.ebs_csi_driver_assume_role.json
  tags               = var.tags
}

# Custom least-privilege IAM policy for EBS CSI Driver
resource "aws_iam_role_policy" "ebs_csi_driver" {
  count = var.enable_ebs_csi_driver ? 1 : 0

  name = "${var.cluster_name}-ebs-csi-driver-policy"
  role = aws_iam_role.ebs_csi_driver[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EBSCSIVolumeManagement"
        Effect = "Allow"
        Action = [
          "ec2:CreateVolume",
          "ec2:DeleteVolume",
          "ec2:AttachVolume",
          "ec2:DetachVolume",
          "ec2:ModifyVolume"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = data.aws_region.current.region
          }
        }
      },
      {
        Sid    = "EBSCSISnapshotManagement"
        Effect = "Allow"
        Action = [
          "ec2:CreateSnapshot",
          "ec2:DeleteSnapshot"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = data.aws_region.current.region
          }
        }
      },
      {
        Sid    = "EBSCSIDescribeOperations"
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeSnapshots",
          "ec2:DescribeVolumes",
          "ec2:DescribeAvailabilityZones"
        ]
        Resource = "*"
      },
      {
        Sid    = "EBSCSITaggingOperations"
        Effect = "Allow"
        Action = [
          "ec2:CreateTags",
          "ec2:DescribeTags"
        ]
        Resource = [
          "arn:aws:ec2:*:*:volume/*",
          "arn:aws:ec2:*:*:snapshot/*"
        ]
        Condition = {
          StringEquals = {
            "ec2:CreateAction" = [
              "CreateVolume",
              "CreateSnapshot"
            ]
          }
        }
      }
    ]
  })
}

# EBS CSI Driver Add-on
resource "aws_eks_addon" "ebs_csi_driver" {
  count = var.enable_ebs_csi_driver ? 1 : 0

  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "aws-ebs-csi-driver"
  addon_version               = var.ebs_csi_driver_version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  service_account_role_arn    = aws_iam_role.ebs_csi_driver[0].arn

  depends_on = [
    aws_eks_node_group.default,
    aws_iam_role_policy.ebs_csi_driver[0]
  ]

  tags = var.tags
}

# =============================================================================
# Shared ALB Functionality (Custom - not in external module)
# =============================================================================

# Get the shared ALB created by AWS Load Balancer Controller
# Using a static key to avoid for_each issues with unknown values
data "aws_lbs" "shared_alb" {
  count = var.enable_shared_alb && var.shared_alb_ingress_group_name != "" ? 1 : 0

  tags = {
    "elbv2.k8s.aws/cluster" = module.eks.cluster_name
    "ingress.k8s.aws/stack" = var.shared_alb_ingress_group_name
  }

  depends_on = [
    module.eks
  ]
}

locals {
  # Get the first ALB ARN if available
  # Convert set to list first, then get first element
  shared_alb_arns_list = var.enable_shared_alb && var.shared_alb_ingress_group_name != "" && length(try(data.aws_lbs.shared_alb[0].arns, [])) > 0 ? tolist(data.aws_lbs.shared_alb[0].arns) : []
  shared_alb_arn       = length(local.shared_alb_arns_list) > 0 ? local.shared_alb_arns_list[0] : null

  # Merge VPC CIDR with allowed IPs
  # VPC CIDR is always included for internal ALB health checks and internal traffic
  # Remove duplicates in case user already included VPC CIDR in their allowed IPs
  shared_alb_allowed_cidrs = var.enable_shared_alb && length(var.shared_alb_allowed_ips) > 0 ? distinct(concat(
    [data.aws_vpc.this.cidr_block],
    var.shared_alb_allowed_ips
  )) : []
}

# Get ALB details (using conditional to avoid for_each with unknown values)
data "aws_lb" "shared_alb_details" {
  count = local.shared_alb_arn != null ? 1 : 0
  arn   = local.shared_alb_arn
}

# =============================================================================
# Security Group for Shared ALB
# Restricts access to allowed IPs when shared_alb_allowed_ips is configured
# =============================================================================

resource "aws_security_group" "shared_alb" {
  count = var.enable_shared_alb && length(var.shared_alb_allowed_ips) > 0 ? 1 : 0

  name        = "${var.cluster_name}-shared-alb"
  description = "Security group for shared ALB with IP restrictions"
  vpc_id      = var.vpc_id

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-shared-alb"
    }
  )
}

# Allow HTTP from VPC CIDR + allowed IPs
resource "aws_security_group_rule" "shared_alb_http_ingress" {
  count = var.enable_shared_alb && length(var.shared_alb_allowed_ips) > 0 ? 1 : 0

  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = local.shared_alb_allowed_cidrs
  security_group_id = aws_security_group.shared_alb[0].id
  description       = "Allow HTTP from VPC CIDR and allowed IPs"
}

# Allow HTTPS from VPC CIDR + allowed IPs
resource "aws_security_group_rule" "shared_alb_https_ingress" {
  count = var.enable_shared_alb && length(var.shared_alb_allowed_ips) > 0 ? 1 : 0

  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = local.shared_alb_allowed_cidrs
  security_group_id = aws_security_group.shared_alb[0].id
  description       = "Allow HTTPS from VPC CIDR and allowed IPs"
}

# Allow HTTPS from GitHub webhook IPs (required for GitHub webhooks to reach /atlantis/events)
# These IPs are specifically for GitHub webhook deliveries only
# Source: https://api.github.com/meta (hooks section)
resource "aws_security_group_rule" "shared_alb_https_github_webhooks" {
  count = var.enable_shared_alb && length(var.shared_alb_allowed_ips) > 0 ? 1 : 0

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
  count = var.enable_shared_alb && length(var.shared_alb_allowed_ips) > 0 ? 1 : 0

  type              = "egress"
  from_port         = 0
  to_port           = 65535
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.shared_alb[0].id
  description       = "Allow all outbound traffic"
}

# =============================================================================
# Allow ALB to communicate with nodes
# When using a custom ALB security group, we need to ensure nodes allow
# traffic from the ALB security group for health checks and backend traffic
# =============================================================================

# Get the node security group from the node group
# EKS automatically creates a security group for the node group and tags it
# We find it by the cluster name tag - EKS tags all cluster resources with this
data "aws_security_groups" "node_security_groups" {
  count = var.enable_shared_alb && length(var.shared_alb_allowed_ips) > 0 ? 1 : 0

  filter {
    name   = "tag:kubernetes.io/cluster/${var.cluster_name}"
    values = ["owned"]
  }

  # Filter for node security groups - they're typically tagged with eks:nodegroup-name
  # or we can find them by excluding the cluster security group
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }

  depends_on = [module.eks]
}

# Allow traffic from ALB security group to node security groups
# This allows the ALB to perform health checks and forward traffic to pods
# Note: We allow all TCP ports (0-65535) to cover all possible service ports
# Using a static map with known keys to avoid for_each issues with unknown values
resource "aws_security_group_rule" "node_from_alb" {
  for_each = try(toset(data.aws_security_groups.node_security_groups[0].ids), toset([]))

  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.shared_alb[0].id
  security_group_id        = each.value
  description              = "Allow traffic from shared ALB security group to nodes"
}
