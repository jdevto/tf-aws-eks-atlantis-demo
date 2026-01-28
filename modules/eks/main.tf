# =============================================================================
# EKS Cluster using external module
# =============================================================================

module "eks" {
  source = "tfstack/eks-basic/aws"

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

  # Addons
  enable_ebs_csi_driver  = var.enable_ebs_csi_driver
  ebs_csi_driver_version = var.ebs_csi_driver_version

  enable_aws_lb_controller       = var.enable_aws_lb_controller
  aws_lb_controller_helm_version = var.aws_lb_controller_helm_version

  enable_pod_identity_agent = var.enable_pod_identity_agent

  # Cluster admin access entries
  cluster_admin_arns = var.cluster_admin_arns

  # Cluster authentication mode
  cluster_authentication_mode = var.cluster_authentication_mode

  tags = var.tags
}

module "shared_alb" {
  source = "./shared-alb"

  enable             = var.enable_shared_alb
  name               = var.shared_alb_name != "" ? var.shared_alb_name : var.cluster_name
  cluster_name       = module.eks.cluster_name
  vpc_id             = var.vpc_id
  ingress_group_name = var.shared_alb_ingress_group_name
  allowed_ips        = var.shared_alb_allowed_ips
  tags               = var.tags

  depends_on = [module.eks]
}
