locals {
  name                          = "${var.cluster_name}-${random_id.suffix.hex}"
  cluster_name                  = var.cluster_name
  region                        = var.region
  shared_alb_ingress_group_name = "platform"

  common_tags = merge(
    var.tags,
    {
      Name        = "test"
      Environment = "dev"
      Project     = "test"
    }
  )
}
