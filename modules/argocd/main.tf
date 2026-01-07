resource "helm_release" "argocd" {
  name             = "argocd"
  namespace        = var.namespace
  create_namespace = true
  repository       = "https://k8sforge.github.io/argocd-chart"
  chart            = "argocd"
  version          = var.chart_version

  wait      = true
  skip_crds = true # Skip CRDs to reduce release manifest size (avoids "Request entity too large" error)

  values = [
    yamlencode({
      argocd = {
        enabled = true
      }
      "argo-cd" = {
        server = {
          service = {
            type = "ClusterIP"
            port = 80
          }
          insecure = true
        }
        configs = {
          params = {
            "server.insecure" = "true"
          }
        }
      }
      ingress = {
        enabled          = true
        ingressClassName = "alb"
        hosts            = [] # Accept any host to allow direct ALB DNS access
        annotations = merge(
          {
            "alb.ingress.kubernetes.io/scheme"           = "internet-facing"
            "alb.ingress.kubernetes.io/target-type"      = "ip"
            "alb.ingress.kubernetes.io/subnets"          = join(",", var.subnet_ids)
            "alb.ingress.kubernetes.io/backend-protocol" = "HTTP"
          },
          # HTTP-only configuration
          !var.enable_https ? {
            "alb.ingress.kubernetes.io/listen-ports" = "[{\"HTTP\": 80}]"
          } : {},
          # HTTPS configuration (base)
          var.enable_https ? {
            "alb.ingress.kubernetes.io/listen-ports"    = "[{\"HTTP\": 80}, {\"HTTPS\": 443}]"
            "alb.ingress.kubernetes.io/certificate-arn" = var.certificate_arn
            "alb.ingress.kubernetes.io/ssl-policy"      = "ELBSecurityPolicy-TLS13-1-2-2021-06"
          } : {},
          # HTTPS redirect (optional)
          var.enable_https && var.ssl_redirect ? {
            "alb.ingress.kubernetes.io/ssl-redirect" = "443"
          } : {}
        )
      }
      healthCheck = {
        enabled  = true
        path     = "/healthz"
        protocol = "HTTP"
        port     = "traffic-port"
      }
      rollouts = {
        enabled = true # Installs Argo Rollouts controller and configures ArgoCD support
      }
      "argo-rollouts" = {
        # Argo Rollouts controller configuration
        # Leave empty for defaults, or add custom values here
      }
    })
  ]
}

# Read the ArgoCD admin credentials from the Kubernetes secret
data "kubernetes_secret" "argocd_admin" {
  metadata {
    name      = "argocd-initial-admin-secret"
    namespace = var.namespace
  }

  depends_on = [helm_release.argocd]
}

# Get the ArgoCD server Ingress to retrieve the ALB endpoint
data "kubernetes_ingress_v1" "argocd_server" {
  metadata {
    name      = "argocd-server"
    namespace = var.namespace
  }

  depends_on = [helm_release.argocd]
}

# Get the ALB by its DNS name
data "aws_lb" "argocd" {
  tags = {
    "elbv2.k8s.aws/cluster" = var.cluster_name
    "ingress.k8s.aws/stack" = "argocd/argocd-ingress"
  }

  depends_on = [helm_release.argocd]
}
