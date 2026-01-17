# ============================================================================
# INGRESS
# ============================================================================
# Creates AWS ALB Ingress for external access to Atlantis
# Uses shared ALB with path prefix support

resource "kubectl_manifest" "atlantis_ingress" {
  yaml_body = yamlencode({
    apiVersion = "networking.k8s.io/v1"
    kind       = "Ingress"
    metadata = {
      name      = "atlantis"
      namespace = var.atlantis_namespace
      annotations = merge(
        {
          "alb.ingress.kubernetes.io/scheme"           = "internet-facing"
          "alb.ingress.kubernetes.io/target-type"      = "ip"
          "alb.ingress.kubernetes.io/subnets"          = join(",", var.subnet_ids)
          "alb.ingress.kubernetes.io/backend-protocol" = "HTTP"
          "alb.ingress.kubernetes.io/healthcheck-path" = "${var.atlantis_path_prefix}/healthz"
          "alb.ingress.kubernetes.io/group.name"       = var.shared_alb_ingress_group_name
        },
        # Security group for IP restrictions (if provided)
        var.shared_alb_security_group_id != "" ? {
          "alb.ingress.kubernetes.io/security-groups" = var.shared_alb_security_group_id
        } : {},
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
    spec = {
      ingressClassName = "alb"
      rules = [
        {
          http = {
            paths = [
              {
                path     = var.atlantis_path_prefix
                pathType = "Prefix"
                backend = {
                  service = {
                    name = "atlantis-nginx-proxy"
                    port = {
                      number = 80
                    }
                  }
                }
              }
            ]
          }
        }
      ]
    }
  })

  depends_on = [
    kubernetes_namespace.atlantis,
    kubectl_manifest.atlantis_application,
    kubectl_manifest.atlantis_nginx_service
  ]
}
