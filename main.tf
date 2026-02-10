module "vpc" {
  source = "cloudbuildlab/vpc/aws"

  vpc_name           = local.name
  vpc_cidr           = "10.0.0.0/16"
  availability_zones = ["${var.region}a", "${var.region}b"]

  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.101.0/24", "10.0.102.0/24"]

  # Enable IPv6 support
  assign_generated_ipv6_cidr_block = true

  # Enable Internet Gateway & NAT Gateway
  create_igw       = true
  nat_gateway_type = "single"

  enable_eks_tags  = true
  eks_cluster_name = var.cluster_name

  tags = local.common_tags
}

# # VPC Module
# module "vpc" {
#   source = "./modules/vpc"

#   name               = var.cluster_name
#   cluster_name       = var.cluster_name
#   availability_zones = ["${var.region}a", "${var.region}b"]

#   tags = merge(local.common_tags, {
#     "kubernetes.io/cluster/${var.cluster_name}" = "owned"
#   })
# }

# module "s3-backend" {
#   source = "./modules/s3"

#   name              = local.name
#   enable_versioning = var.s3_enable_versioning
#   s3_force_destroy  = var.s3_force_destroy
#   tags              = local.common_tags
# }

module "eks" {
  source = "tfstack/eks-basic/aws"

  name               = var.cluster_name
  kubernetes_version = var.cluster_version
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = concat(module.vpc.public_subnet_ids, module.vpc.private_subnet_ids)

  endpoint_public_access = true

  access_entries                      = var.access_entries
  enable_aws_load_balancer_controller = var.enable_aws_load_balancer_controller

  addons = {
    coredns = {
      addon_version = "v1.13.2-eksbuild.1"
    }
    eks-pod-identity-agent = {
      before_compute = true
      addon_version  = "v1.3.10-eksbuild.2"
    }
    kube-proxy = {
      addon_version = "v1.35.0-eksbuild.2"
    }
    vpc-cni = {
      before_compute = true
      addon_version  = "v1.21.1-eksbuild.3"
      configuration_values = jsonencode({
        enableNetworkPolicy = "true"
        nodeAgent = {
          enablePolicyEventLogs = "true"
        }
      })
    }
  }

  eks_managed_node_groups = {
    one = {
      name           = "node-group-1"
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = ["t3a.large"]

      min_size     = 3
      max_size     = 3
      desired_size = 3

      metadata_options = {
        http_endpoint               = "enabled"
        http_tokens                 = "required"
        http_put_response_hop_limit = 1
      }
    }
  }

  depends_on = [module.vpc]
}

# # EKS Module
# module "eks" {
#   source = "./modules/eks"

#   cluster_name          = local.cluster_name
#   cluster_version       = var.cluster_version
#   enable_ebs_csi_driver = var.enable_ebs_csi_driver
#   # Cluster control plane can use both public and private subnets
#   subnet_ids = concat(module.vpc.private_subnet_ids, module.vpc.public_subnet_ids)
#   # Node groups should be in private subnets only for security
#   node_subnet_ids = module.vpc.private_subnet_ids
#   vpc_id          = module.vpc.vpc_id
#   tags            = local.common_tags

#   # Enable Pod Identity Agent for AWS SDK credentials in pods
#   enable_pod_identity_agent = var.enable_pod_identity_agent

#   # Cluster admin access entries
#   cluster_admin_arns = var.cluster_admin_arns

#   # Cluster authentication mode
#   cluster_authentication_mode = var.cluster_authentication_mode

#   # Shared ALB configuration
#   enable_shared_alb             = var.enable_shared_alb
#   public_subnet_ids             = module.vpc.public_subnet_ids # Pass public subnets for ALB
#   shared_alb_ingress_group_name = local.shared_alb_ingress_group_name
#   shared_alb_allowed_ips        = var.shared_alb_allowed_ips
#   shared_alb_name               = local.cluster_name

#   depends_on = [module.vpc]
# }

# # Landing Page Module
# module "landing_page" {
#   source = "./modules/landing-page"

#   count = var.enable_shared_alb ? 1 : 0

#   subnet_ids                    = module.vpc.public_subnet_ids
#   shared_alb_ingress_group_name = local.shared_alb_ingress_group_name
#   shared_alb_security_group_id  = module.eks.shared_alb_security_group_id
#   enable_https                  = var.enable_https
#   certificate_arn               = var.enable_https ? var.certificate_arn : ""
#   ssl_redirect                  = var.enable_https
#   domain_name                   = var.domain_name
#   alb_arn                       = module.eks.shared_alb_arn
#   route53_name                  = "platform"

#   # Services to display on landing page
#   services = [
#     {
#       name        = "ArgoCD"
#       url         = var.enable_https ? "https://argocd.${var.domain_name}" : "http://argocd.${var.domain_name}"
#       description = "GitOps continuous delivery tool for Kubernetes. Manage your applications declaratively with automated sync and rollback capabilities."
#     },
#     {
#       name        = "Atlantis"
#       url         = var.enable_https ? "https://atlantis.${var.domain_name}" : "http://atlantis.${var.domain_name}"
#       description = "Terraform automation via pull requests. Review and apply infrastructure changes safely through your Git workflow."
#     }
#   ]

#   depends_on = [module.eks]
# }

# # ArgoCD Module
# module "argocd" {
#   source = "./modules/argocd"

#   aws_region                    = var.region
#   cluster_name                  = module.eks.cluster_name
#   subnet_ids                    = module.vpc.public_subnet_ids
#   enable_https                  = var.enable_https
#   certificate_arn               = var.certificate_arn
#   ssl_redirect                  = var.enable_https
#   shared_alb_ingress_group_name = local.shared_alb_ingress_group_name
#   shared_alb_security_group_id  = module.eks.shared_alb_security_group_id
#   domain_name                   = var.domain_name
#   alb_arn                       = module.eks.shared_alb_arn
#   route53_name                  = "argocd"

#   depends_on = [
#     module.eks
#   ]
# }

# # Bitwarden Secrets Manager Module
# module "bitwarden" {
#   source = "./modules/bitwarden"

#   count = var.bitwarden_enable ? 1 : 0

#   organization_id = var.bitwarden_organization_id
#   access_token    = var.bitwarden_access_token

#   operator_helm_version               = var.bitwarden_operator_helm_version
#   bw_secrets_manager_refresh_interval = var.bitwarden_bw_secrets_manager_refresh_interval
#   manager_image_tag                   = var.bitwarden_manager_image_tag
#   replicas                            = var.bitwarden_replicas
#   update_strategy                     = var.bitwarden_update_strategy

#   cluster_endpoint = module.eks.cluster_endpoint
#   cluster_ca_data  = module.eks.cluster_ca_data
#   cluster_name     = module.eks.cluster_name
#   argocd_namespace = module.argocd.argocd_namespace
#   secrets          = var.bitwarden_secrets

#   tags = local.common_tags

#   depends_on = [
#     module.eks
#   ]
# }

# # Atlantis Module
# module "atlantis" {
#   source = "./modules/atlantis"

#   count = var.bitwarden_enable ? 1 : 0

#   aws_region      = var.region
#   cluster_name    = module.eks.cluster_name
#   subnet_ids      = module.vpc.public_subnet_ids
#   enable_https    = var.enable_https
#   certificate_arn = var.certificate_arn
#   ssl_redirect    = var.enable_https
#   domain_name     = var.domain_name
#   github_owner    = var.github_owner

#   # GitHub credentials from Bitwarden-synced Kubernetes secrets
#   bitwarden_secrets_namespace      = module.bitwarden[0].secrets_namespace
#   bitwarden_organization_id        = var.bitwarden_organization_id
#   bitwarden_auth_token_secret_name = module.bitwarden[0].auth_secret_name
#   bitwarden_auth_token_secret_key  = "token"

#   # Bitwarden secret IDs for GitHub credentials (used to sync secrets to atlantis namespace)
#   github_app_id_secret_id          = var.bitwarden_secrets["dev-github-app-id"]
#   github_app_private_key_secret_id = var.bitwarden_secrets["dev-github-app-private-key"]
#   github_webhook_secret_id         = var.bitwarden_secrets["dev-github-webhook-secret"]

#   # GitHub App secret names (with dev- prefix for this environment)
#   # The secret name is also used as the key name within the secret
#   github_app_id_secret_name          = "dev-github-app-id"
#   github_app_private_key_secret_name = "dev-github-app-private-key"
#   github_webhook_secret_name         = "dev-github-webhook-secret"

#   state_bucket_name             = module.s3-backend.state_bucket_name
#   shared_alb_ingress_group_name = local.shared_alb_ingress_group_name
#   shared_alb_security_group_id  = module.eks.shared_alb_security_group_id
#   argocd_namespace              = "argocd" # Must match the namespace where ArgoCD is installed
#   alb_arn                       = module.eks.shared_alb_arn
#   route53_name                  = "atlantis"

#   depends_on = [
#     module.argocd,
#     module.bitwarden[0]
#   ]
# }

# # GitHub Terraform AWS Module
# module "github_terraform_aws" {
#   source = "./modules/github-terraform-aws"

#   repository_name       = "atlantis-terraform-aws"
#   github_owner          = var.github_owner
#   github_webhook_secret = var.github_webhook_secret
#   atlantis_url          = var.enable_https ? "https://atlantis.${var.domain_name}" : "http://atlantis.${var.domain_name}"
#   state_bucket_name     = module.s3-backend.state_bucket_name
#   region                = var.region
# }

# # # GitHub Terraform GitHub Module (commented out - not currently used)
# # module "github_terraform_github" {
# #   source = "./modules/github-terraform-github"
# #
# #   repository_name       = "atlantis-terraform-github"
# #   github_owner          = var.github_owner
# #   github_webhook_secret = var.github_webhook_secret
# #   atlantis_url          = var.enable_https ? "https://atlantis.${var.domain_name}" : "http://atlantis.${var.domain_name}"
# #   state_bucket_name     = module.s3-backend.state_bucket_name
# #   region                = var.region
# # }
