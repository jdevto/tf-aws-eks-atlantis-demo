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

# EKS Module
module "eks" {
  source = "./modules/eks"

  cluster_name    = local.cluster_name
  cluster_version = var.cluster_version
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

  repo_url        = var.repo_url
  target_revision = var.target_revision
  aws_region      = var.region
  cluster_name    = module.eks.cluster_name
  subnet_ids      = module.vpc.public_subnet_ids
}
