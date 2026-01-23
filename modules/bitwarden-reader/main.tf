# Note: Namespace is created by the bitwarden module, so we don't create it here
# We just reference it via var.namespace

# Register Helm repository for bitwarden-reader in ArgoCD
resource "kubectl_manifest" "bitwarden_reader_helm_repo" {
  count = var.enable ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "v1"
    kind       = "Secret"
    metadata = {
      name      = "bitwarden-reader-chart-repo"
      namespace = var.argocd_namespace
      labels = {
        "argocd.argoproj.io/secret-type" = "repository"
      }
    }
    stringData = {
      type    = "helm"
      name    = "bitwarden-reader-chart"
      url     = "https://k8sforge.github.io/bitwarden-reader-chart"
      project = "default"
    }
  })
}

# ArgoCD Application for Bitwarden Reader
resource "kubectl_manifest" "bitwarden_reader_application" {
  count = var.enable ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name       = var.app_name
      namespace  = var.argocd_namespace
      finalizers = ["resources-finalizer.argocd.argoproj.io"]
    }

    spec = {
      project = "default"

      source = {
        repoURL        = "https://k8sforge.github.io/bitwarden-reader-chart"
        chart          = "bitwarden-reader"
        targetRevision = var.chart_version != null ? var.chart_version : "*"

        helm = {
          values = yamlencode({
            namespace = {
              name   = var.namespace
              create = false # Namespace is created by Terraform
            }
            image = {
              repository = length(split(":", var.image)) > 1 ? split(":", var.image)[0] : var.image
              tag        = length(split(":", var.image)) > 1 ? split(":", var.image)[1] : "latest"
              pullPolicy = var.image_pull_policy
            }
            replicaCount = 1 # Single replica, no HA needed
            app = {
              secretNames = var.secret_names
            }
            service = {
              enabled = true
              type    = "ClusterIP"
              port    = 8080
              name    = var.app_name # Ensure service name matches what we reference in ingress
            }
            ingress = {
              enabled = false # Disable ingress in helm chart - we'll create a dedicated ingress resource
            }
            livenessProbe = {
              httpGet = {
                path = "/api/v1/health"
                port = 8080
              }
              initialDelaySeconds = 60
              periodSeconds       = 30
              timeoutSeconds      = 5
              failureThreshold    = 3
            }
            readinessProbe = {
              httpGet = {
                path = "/api/v1/health"
                port = 8080
              }
              initialDelaySeconds = 60
              periodSeconds       = 10
              timeoutSeconds      = 5
              failureThreshold    = 3
            }
          })
        }
      }

      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = var.namespace
      }

      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = ["CreateNamespace=true"]
      }

      ignoreDifferences = [
        {
          group        = "apps"
          kind         = "Deployment"
          jsonPointers = ["/status"]
        },
        {
          group        = "networking.k8s.io"
          kind         = "Ingress"
          jsonPointers = ["/status"]
        }
      ]
    }
  })

  wait = true

  depends_on = [
    kubectl_manifest.bitwarden_reader_helm_repo[0]
  ]
}

# Ingress resource for Bitwarden Reader using shared ALB with host-based routing
resource "kubectl_manifest" "bitwarden_reader_ingress" {
  count = var.enable && var.shared_alb_ingress_group_name != "" ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "networking.k8s.io/v1"
    kind       = "Ingress"
    metadata = {
      name      = var.app_name
      namespace = var.namespace
      annotations = merge(
        {
          "alb.ingress.kubernetes.io/scheme"           = "internet-facing"
          "alb.ingress.kubernetes.io/target-type"      = "ip"
          "alb.ingress.kubernetes.io/subnets"          = join(",", var.subnet_ids)
          "alb.ingress.kubernetes.io/backend-protocol" = "HTTP"
          "alb.ingress.kubernetes.io/healthcheck-path" = "/api/v1/health"
          "alb.ingress.kubernetes.io/group.name"       = var.shared_alb_ingress_group_name
          "alb.ingress.kubernetes.io/order"            = "10"
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
          host = "reader.${var.domain_name}"
          http = {
            paths = [
              {
                path     = "/"
                pathType = "Prefix"
                backend = {
                  service = {
                    name = var.app_name
                    port = {
                      number = 8080
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
    kubectl_manifest.bitwarden_reader_application[0]
  ]
}

data "kubernetes_ingress_v1" "reader" {
  count = var.enable && var.shared_alb_ingress_group_name != "" ? 1 : 0

  metadata {
    name      = var.app_name
    namespace = var.namespace
  }

  depends_on = [kubectl_manifest.bitwarden_reader_ingress[0]]
}
