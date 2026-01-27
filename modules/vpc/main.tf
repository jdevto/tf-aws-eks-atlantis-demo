# =============================================================================
# VPC using external module
# =============================================================================

module "vpc" {
  source = "cloudbuildlab/vpc/aws"

  vpc_name = var.name
  vpc_cidr = "10.0.0.0/16"

  # DNS Configuration
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Subnet configuration
  availability_zones = var.availability_zones

  # Calculate subnet CIDRs to match original behavior
  # Public: 10.0.1.0/24, 10.0.2.0/24, etc. (using /8 split, starting at index 1)
  # Private: 10.0.11.0/24, 10.0.12.0/24, etc. (using /8 split, starting at index 10)
  public_subnet_cidrs = [
    for idx in range(length(var.availability_zones)) : cidrsubnet("10.0.0.0/16", 8, idx + 1)
  ]
  private_subnet_cidrs = [
    for idx in range(length(var.availability_zones)) : cidrsubnet("10.0.0.0/16", 8, idx + 10)
  ]

  # NAT Gateway configuration
  enable_nat_gateway = true
  nat_gateway_type   = var.one_nat_gateway_per_az ? "one_per_az" : "single"

  # EKS Configuration
  enable_eks_tags  = true
  eks_cluster_name = var.cluster_name

  # Tags
  tags = var.tags
}
