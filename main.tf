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

  name                                 = local.name
  enable_versioning                    = var.s3_enable_versioning
  s3_force_destroy                     = var.s3_force_destroy
  dynamodb_deletion_protection_enabled = var.dynamodb_deletion_protection_enabled
  tags                                 = local.common_tags
}

# EKS Module
module "eks" {
  source = "./modules/eks"

  cluster_name          = local.cluster_name
  cluster_version       = var.cluster_version
  enable_ebs_csi_driver = var.enable_ebs_csi_driver
  # Cluster control plane can use both public and private subnets
  subnet_ids = concat(module.vpc.private_subnet_ids, module.vpc.public_subnet_ids)
  # Node groups should be in private subnets only for security
  node_subnet_ids = module.vpc.private_subnet_ids
  vpc_id          = module.vpc.vpc_id
  tags            = local.common_tags
}

# ArgoCD and Bootstrap Module
module "argocd" {
  source = "./modules/argocd"

  aws_region             = var.region
  cluster_name           = module.eks.cluster_name
  subnet_ids             = module.vpc.public_subnet_ids
  enable_https           = var.enable_https
  certificate_arn        = var.enable_https ? data.aws_acm_certificate.web.arn : ""
  domain_name            = var.domain_name
  github_owner           = var.github_owner
  github_app_id          = var.github_app_id
  github_app_private_key = var.github_app_private_key
  github_webhook_secret  = var.github_webhook_secret
  state_bucket_name      = module.s3-backend.state_bucket_name
  state_lock_table       = module.s3-backend.lock_table_name
}

module "route53-argocd" {
  source = "./modules/route53"

  name         = "argocd"
  domain_name  = var.domain_name
  alb_dns_name = module.argocd.argocd_alb_dns_name
  alb_zone_id  = module.argocd.argocd_alb_zone_id
}

module "route53-atlantis" {
  source = "./modules/route53"

  name         = "atlantis"
  domain_name  = var.domain_name
  alb_dns_name = module.argocd.atlantis_alb_dns_name
  alb_zone_id  = module.argocd.atlantis_alb_zone_id
}

module "github" {
  source = "./modules/github"

  repository_name       = var.demo_repo_name
  github_owner          = var.github_owner
  github_app_id         = var.github_app_id
  github_webhook_secret = var.github_webhook_secret
  atlantis_url          = "https://${module.route53-atlantis.custom_domain}"
  state_bucket_name     = module.s3-backend.state_bucket_name
  state_lock_table      = module.s3-backend.lock_table_name
  region                = var.region
}
