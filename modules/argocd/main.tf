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
          # Configure ArgoCD to serve from /argocd subpath
          rootpath = "/argocd"
          basehref = "/argocd"
          # Additional server configuration for subpath
          extraArgs = [
            "--rootpath=/argocd",
            "--basehref=/argocd"
          ]
        }
        configs = {
          params = {
            "server.insecure" = "true"
            "server.rootpath" = "/argocd"
            "server.basehref" = "/argocd"
            # Set the URL to help ArgoCD generate correct basehref
            "server.url" = var.enable_https ? "https://${var.domain_name}/argocd" : "http://${var.domain_name}/argocd"
          }
        }
      }
      ingress = {
        enabled = false # Disable ingress in helm chart - we'll create a dedicated ingress resource
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

# Dedicated Ingress resource for ArgoCD using shared ALB
resource "kubernetes_ingress_v1" "argocd" {
  metadata {
    name      = "argocd-server"
    namespace = var.namespace
    annotations = merge(
      {
        "alb.ingress.kubernetes.io/scheme"           = "internet-facing"
        "alb.ingress.kubernetes.io/target-type"      = "ip"
        "alb.ingress.kubernetes.io/subnets"          = join(",", var.subnet_ids)
        "alb.ingress.kubernetes.io/backend-protocol" = "HTTP"
        "alb.ingress.kubernetes.io/group.name"       = var.shared_alb_ingress_group_name
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

  spec {
    ingress_class_name = "alb"

    rule {
      http {
        path {
          path      = "/argocd"
          path_type = "Prefix"
          backend {
            service {
              name = "argocd-server"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.argocd]
}

# Patch the ArgoCD ConfigMap to set correct URL
# The Helm chart doesn't always apply these values correctly
# Use force=true to override Helm's field management
resource "kubernetes_config_map_v1_data" "argocd_cm_patch" {
  metadata {
    name      = "argocd-cm"
    namespace = var.namespace
  }

  force = true

  data = {
    url = var.enable_https ? "https://${var.domain_name}/argocd" : "http://${var.domain_name}/argocd"
  }

  depends_on = [helm_release.argocd]
}

# Get the ArgoCD server Ingress to retrieve the ALB endpoint
data "kubernetes_ingress_v1" "argocd_server" {
  metadata {
    name      = "argocd-server"
    namespace = var.namespace
  }

  depends_on = [kubernetes_ingress_v1.argocd]
}
