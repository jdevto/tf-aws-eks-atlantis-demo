# =============================================================================
# AWS Load Balancer Controller Helm Release
# =============================================================================
# This deploys the AWS Load Balancer Controller to the EKS cluster
# The controller watches for Kubernetes Ingress resources and creates ALBs/NLBs
#
# Note: The IAM role and service account are already created by the EKS module
# This just deploys the controller application itself
#
# If HTTPS (443) host-based routing stops working on the shared ALB (ingress group),
# the controller may have failed to sync rules to the 443 listener. Restart it to
# force reconciliation: kubectl rollout restart deployment/aws-load-balancer-controller -n kube-system

# Create the service account with IRSA annotation
resource "kubernetes_service_account" "aws_load_balancer_controller" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = module.eks.aws_load_balancer_controller_role_arn
    }
  }

  depends_on = [module.eks]
}

# Deploy AWS Load Balancer Controller via Helm
resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.7.2"

  set {
    name  = "clusterName"
    value = module.eks.cluster_name
  }

  set {
    name  = "serviceAccount.create"
    value = "false"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "region"
    value = var.region
  }

  set {
    name  = "vpcId"
    value = module.vpc.vpc_id
  }

  depends_on = [
    module.eks,
    kubernetes_service_account.aws_load_balancer_controller
  ]
}
