locals {
  cluster_name = var.cluster_name
  region       = var.region

  common_tags = merge(
    var.tags,
    {
      Name        = "test"
      Environment = "dev"
      Project     = "test"
    }
  )
}
