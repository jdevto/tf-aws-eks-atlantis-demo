# VPC Module
module "vpc" {
  source = "./modules/vpc"

  name               = var.cluster_name
  cluster_name       = var.cluster_name
  availability_zones = ["${var.region}a", "${var.region}b"]

  tags = merge(local.common_tags, {
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  })
}

module "s3-backend" {
  source = "./modules/s3"

  name              = local.name
  enable_versioning = var.s3_enable_versioning
  s3_force_destroy  = var.s3_force_destroy
  tags              = local.common_tags
}

# EKS Module
module "eks" {
  source = "./modules/eks"

  cluster_name                  = local.cluster_name
  cluster_version               = var.cluster_version
  enable_ebs_csi_driver         = var.enable_ebs_csi_driver
  enable_shared_alb             = var.enable_shared_alb
  shared_alb_ingress_group_name = var.enable_shared_alb ? "platform" : ""
  # Cluster control plane can use both public and private subnets
  subnet_ids = concat(module.vpc.private_subnet_ids, module.vpc.public_subnet_ids)
  # Node groups should be in private subnets only for security
  node_subnet_ids = module.vpc.private_subnet_ids
  vpc_id          = module.vpc.vpc_id
  tags            = local.common_tags

  # AWS Auth ConfigMap - map IAM users and roles for Kubernetes access
  aws_auth_map_users = var.aws_auth_map_users
  aws_auth_map_roles = var.aws_auth_map_roles

  # Shared ALB IP restrictions
  shared_alb_allowed_ips = var.shared_alb_allowed_ips
}

module "route53_platform" {
  source = "./modules/route53"

  count = var.enable_shared_alb ? 1 : 0

  name         = "platform" # Creates: platform.example.com
  domain_name  = var.domain_name
  alb_dns_name = module.eks.shared_alb_dns_name
  alb_zone_id  = module.eks.shared_alb_zone_id
}

# Landing Page Module
module "landing_page" {
  source = "./modules/landing-page"

  count = var.enable_shared_alb ? 1 : 0

  subnet_ids                    = module.vpc.public_subnet_ids
  shared_alb_ingress_group_name = module.eks.shared_alb_ingress_group_name
  shared_alb_security_group_id  = module.eks.shared_alb_security_group_id
  enable_https                  = var.enable_https
  certificate_arn               = var.enable_https ? var.certificate_arn : ""
  ssl_redirect                  = var.enable_https

  # Path prefixes for service links
  argocd_path_prefix           = "/argocd"
  atlantis_path_prefix         = "/atlantis"
  bitwarden_reader_path_prefix = "/reader"

  depends_on = [module.eks]
}

# ArgoCD Module
module "argocd" {
  source = "./modules/argocd"

  aws_region                    = var.region
  cluster_name                  = module.eks.cluster_name
  subnet_ids                    = module.vpc.public_subnet_ids
  enable_https                  = var.enable_https
  certificate_arn               = var.certificate_arn
  ssl_redirect                  = var.enable_https
  shared_alb_ingress_group_name = module.eks.shared_alb_ingress_group_name
  shared_alb_security_group_id  = module.eks.shared_alb_security_group_id
  domain_name                   = var.domain_name
}

# Bitwarden Secrets Manager Module
module "bitwarden" {
  source = "./modules/bitwarden"

  enable          = var.bitwarden_enable
  organization_id = var.bitwarden_organization_id
  access_token    = var.bitwarden_access_token

  operator_helm_version               = var.bitwarden_operator_helm_version
  bw_secrets_manager_refresh_interval = var.bitwarden_bw_secrets_manager_refresh_interval
  manager_image_tag                   = var.bitwarden_manager_image_tag
  replicas                            = var.bitwarden_replicas
  update_strategy                     = var.bitwarden_update_strategy

  cluster_endpoint = module.eks.cluster_endpoint
  cluster_ca_data  = module.eks.cluster_ca_data
  cluster_name     = module.eks.cluster_name
  argocd_namespace = module.argocd.argocd_namespace

  tags = local.common_tags

  depends_on = [
    module.vpc,
    module.eks,
    module.argocd
  ]
}

# Bitwarden Secret Sync Modules
# Create a module instance for each secret in bitwarden_secrets map
module "bitwarden_secrets" {
  source   = "./modules/bitwarden-secret"
  for_each = var.bitwarden_secrets

  name            = each.key
  namespace       = module.bitwarden.secrets_namespace
  organization_id = var.bitwarden_organization_id
  secret_id       = each.value

  access_token_secret_name = module.bitwarden.auth_secret_name
  access_token_secret_key  = "token"

  tags = local.common_tags

  depends_on = [
    module.vpc,
    module.eks,
    module.bitwarden
  ]
}

# Bitwarden Reader Demo Web App
# Demonstrates reading secrets synced from Bitwarden to Kubernetes
module "bitwarden_reader" {
  source = "./modules/bitwarden-reader"

  namespace = module.bitwarden.secrets_namespace
  secret_names = var.bitwarden_reader_secret_names != null ? var.bitwarden_reader_secret_names : (
    [for name, module in module.bitwarden_secrets : module.kubernetes_secret_name]
  )

  # Shared ALB configuration
  shared_alb_ingress_group_name = module.eks.shared_alb_ingress_group_name
  shared_alb_security_group_id  = module.eks.shared_alb_security_group_id
  subnet_ids                    = module.vpc.public_subnet_ids
  path_prefix                   = "/reader"

  # HTTPS configuration
  enable_https    = var.enable_https
  certificate_arn = var.enable_https ? var.certificate_arn : ""
  ssl_redirect    = var.enable_https

  # ArgoCD configuration
  argocd_namespace = module.argocd.argocd_namespace

  tags = local.common_tags

  depends_on = [
    module.vpc,
    module.eks,
    module.argocd,
    module.bitwarden,
    module.bitwarden_secrets
  ]
}

# Atlantis Module
module "atlantis" {
  source = "./modules/atlantis"

  aws_region                    = var.region
  cluster_name                  = module.eks.cluster_name
  subnet_ids                    = module.vpc.public_subnet_ids
  enable_https                  = var.enable_https
  certificate_arn               = var.certificate_arn
  ssl_redirect                  = var.enable_https
  domain_name                   = var.domain_name
  github_owner                  = var.github_owner
  github_app_id                 = var.github_app_id
  github_app_private_key        = var.github_app_private_key
  github_webhook_secret         = var.github_webhook_secret
  state_bucket_name             = module.s3-backend.state_bucket_name
  shared_alb_ingress_group_name = module.eks.shared_alb_ingress_group_name
  shared_alb_security_group_id  = module.eks.shared_alb_security_group_id
  argocd_namespace              = "argocd" # Must match the namespace where ArgoCD is installed

  depends_on = [module.argocd]
}

# GitHub Module
module "github" {
  source = "./modules/github"

  repository_name        = var.demo_repo_name
  github_owner           = var.github_owner
  github_app_id          = var.github_app_id
  github_app_private_key = var.github_app_private_key
  github_webhook_secret  = var.github_webhook_secret
  atlantis_url           = "https://platform.${var.domain_name}/atlantis"
  state_bucket_name      = module.s3-backend.state_bucket_name
  region                 = var.region
}
