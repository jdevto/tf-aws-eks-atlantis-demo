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
}

# In main.tf
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
  enable_https                  = var.enable_https
  certificate_arn               = var.enable_https ? var.certificate_arn : ""
  ssl_redirect                  = var.enable_https ? true : false

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
  ssl_redirect                  = var.enable_https ? true : false
  shared_alb_ingress_group_name = module.eks.shared_alb_ingress_group_name
  domain_name                   = var.domain_name
}

# Atlantis Module
module "atlantis" {
  source = "./modules/atlantis"

  aws_region                    = var.region
  cluster_name                  = module.eks.cluster_name
  subnet_ids                    = module.vpc.public_subnet_ids
  enable_https                  = var.enable_https
  certificate_arn               = var.certificate_arn
  ssl_redirect                  = var.enable_https ? true : false
  domain_name                   = var.domain_name
  github_owner                  = var.github_owner
  github_app_id                 = var.github_app_id
  github_app_private_key        = var.github_app_private_key
  github_webhook_secret         = var.github_webhook_secret
  state_bucket_name             = module.s3-backend.state_bucket_name
  shared_alb_ingress_group_name = module.eks.shared_alb_ingress_group_name
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
