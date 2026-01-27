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

  cluster_name          = local.cluster_name
  cluster_version       = var.cluster_version
  enable_ebs_csi_driver = var.enable_ebs_csi_driver
  # Cluster control plane can use both public and private subnets
  subnet_ids = concat(module.vpc.private_subnet_ids, module.vpc.public_subnet_ids)
  # Node groups should be in private subnets only for security
  node_subnet_ids = module.vpc.private_subnet_ids
  vpc_id          = module.vpc.vpc_id
  tags            = local.common_tags

  # Enable Pod Identity Agent for AWS SDK credentials in pods
  enable_pod_identity_agent = var.enable_pod_identity_agent

  # Cluster admin access entries
  cluster_admin_arns = var.cluster_admin_arns

  # Cluster authentication mode
  cluster_authentication_mode = var.cluster_authentication_mode

  depends_on = [module.vpc]
}

# Shared ALB Module
module "shared_alb" {
  source = "./modules/shared-alb"

  enable             = var.enable_shared_alb
  name               = local.cluster_name
  cluster_name       = module.eks.cluster_name
  vpc_id             = module.vpc.vpc_id
  ingress_group_name = "platform"
  allowed_ips        = var.shared_alb_allowed_ips
  tags               = local.common_tags

  depends_on = [
    module.vpc,
    module.eks
  ]
}

# Landing Page Module
module "landing_page" {
  source = "./modules/landing-page"

  count = var.enable_shared_alb ? 1 : 0

  subnet_ids                    = module.vpc.public_subnet_ids
  shared_alb_ingress_group_name = module.shared_alb.ingress_group_name
  shared_alb_security_group_id  = module.shared_alb.security_group_id
  enable_https                  = var.enable_https
  certificate_arn               = var.enable_https ? var.certificate_arn : ""
  ssl_redirect                  = var.enable_https

  # Services to display on landing page
  services = [
    {
      name        = "ArgoCD"
      url         = var.enable_https ? "https://argocd.${var.domain_name}" : "http://argocd.${var.domain_name}"
      description = "GitOps continuous delivery tool for Kubernetes. Manage your applications declaratively with automated sync and rollback capabilities."
    },
    {
      name        = "Atlantis"
      url         = var.enable_https ? "https://atlantis.${var.domain_name}" : "http://atlantis.${var.domain_name}"
      description = "Terraform automation via pull requests. Review and apply infrastructure changes safely through your Git workflow."
    },
    {
      name        = "Bitwarden Reader"
      url         = var.enable_https ? "https://reader.${var.domain_name}" : "http://reader.${var.domain_name}"
      description = "Demo web interface to view secrets synced from Bitwarden Secrets Manager to Kubernetes."
    }
  ]

  depends_on = [module.eks]
}

module "route53_platform" {
  source = "./modules/route53"

  count = var.enable_shared_alb ? 1 : 0

  name         = "platform" # Creates: platform.example.com
  domain_name  = var.domain_name
  alb_dns_name = module.shared_alb.dns_name
  alb_zone_id  = module.shared_alb.zone_id

  depends_on = [
    module.eks,
    module.landing_page,
  ]
}

module "route53_atlantis" {
  source = "./modules/route53"

  count = var.enable_shared_alb ? 1 : 0

  name         = "atlantis" # Creates: atlantis.dev.geonet.cloud
  domain_name  = var.domain_name
  alb_dns_name = module.shared_alb.dns_name
  alb_zone_id  = module.shared_alb.zone_id

  depends_on = [
    module.eks,
    module.route53_platform,
  ]
}

module "route53_argocd" {
  source = "./modules/route53"

  count = var.enable_shared_alb ? 1 : 0

  name         = "argocd" # Creates: argocd.dev.geonet.cloud
  domain_name  = var.domain_name
  alb_dns_name = module.shared_alb.dns_name
  alb_zone_id  = module.shared_alb.zone_id

  depends_on = [
    module.eks,
    module.route53_platform,
    module.route53_atlantis,
  ]
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
  shared_alb_ingress_group_name = module.shared_alb.ingress_group_name
  shared_alb_security_group_id  = module.shared_alb.security_group_id
  domain_name                   = var.domain_name

  depends_on = [
    module.eks,
    module.landing_page,
    module.route53_argocd,
  ]
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

# Atlantis Module
module "atlantis" {
  source = "./modules/atlantis"

  aws_region      = var.region
  cluster_name    = module.eks.cluster_name
  subnet_ids      = module.vpc.public_subnet_ids
  enable_https    = var.enable_https
  certificate_arn = var.certificate_arn
  ssl_redirect    = var.enable_https
  domain_name     = var.domain_name
  github_owner    = var.github_owner

  # GitHub credentials from Bitwarden-synced Kubernetes secrets
  bitwarden_secrets_namespace      = module.bitwarden.secrets_namespace
  bitwarden_organization_id        = var.bitwarden_organization_id
  bitwarden_auth_token_secret_name = module.bitwarden.auth_secret_name
  bitwarden_auth_token_secret_key  = "token"

  # Bitwarden secret IDs for GitHub credentials (used to sync secrets to atlantis namespace)
  github_app_id_secret_id          = var.bitwarden_secrets["dev-github-app-id"]
  github_app_private_key_secret_id = var.bitwarden_secrets["dev-github-app-private-key"]
  github_webhook_secret_id         = var.bitwarden_secrets["dev-github-webhook-secret"]

  # GitHub App secret names (with dev- prefix for this environment)
  # The secret name is also used as the key name within the secret
  github_app_id_secret_name          = "dev-github-app-id"
  github_app_private_key_secret_name = "dev-github-app-private-key"
  github_webhook_secret_name         = "dev-github-webhook-secret"

  state_bucket_name             = module.s3-backend.state_bucket_name
  shared_alb_ingress_group_name = module.shared_alb.ingress_group_name
  shared_alb_security_group_id  = module.shared_alb.security_group_id
  argocd_namespace              = "argocd" # Must match the namespace where ArgoCD is installed

  depends_on = [
    module.argocd,
    module.bitwarden,
    module.bitwarden_secrets,
    module.route53_atlantis
  ]
}

# GitHub Terraform AWS Module
module "github_terraform_aws" {
  source = "./modules/github-terraform-aws"

  repository_name       = "atlantis-terraform-aws"
  github_owner          = var.github_owner
  github_webhook_secret = var.github_webhook_secret
  atlantis_url          = var.enable_https ? "https://atlantis.${var.domain_name}" : "http://atlantis.${var.domain_name}"
  state_bucket_name     = module.s3-backend.state_bucket_name
  region                = var.region
}

# # GitHub Terraform GitHub Module (commented out - not currently used)
# module "github_terraform_github" {
#   source = "./modules/github-terraform-github"
#
#   repository_name       = "atlantis-terraform-github"
#   github_owner          = var.github_owner
#   github_webhook_secret = var.github_webhook_secret
#   atlantis_url          = var.enable_https ? "https://atlantis.${var.domain_name}" : "http://atlantis.${var.domain_name}"
#   state_bucket_name     = module.s3-backend.state_bucket_name
#   region                = var.region
# }
