# Register Helm repository for atlantis-chart
resource "kubectl_manifest" "atlantis_helm_repo" {
  yaml_body = yamlencode({
    apiVersion = "v1"
    kind       = "Secret"
    metadata = {
      name      = "atlantis-chart-repo"
      namespace = var.argocd_namespace
      labels = {
        "argocd.argoproj.io/secret-type" = "repository"
      }
    }
    stringData = {
      type    = "helm"
      name    = "atlantis-chart"
      url     = "https://k8sforge.github.io/atlantis-chart"
      project = "default"
    }
  })
}

# Bootstrap Argo CD Application for atlantis using Helm chart
resource "kubectl_manifest" "atlantis_application" {
  yaml_body = yamlencode({
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name       = "atlantis"
      namespace  = var.argocd_namespace
      finalizers = ["resources-finalizer.argocd.argoproj.io"]
    }

    spec = {
      project = "default"

      source = {
        repoURL        = "https://k8sforge.github.io/atlantis-chart"
        chart          = "atlantis"
        targetRevision = var.atlantis_chart_version

        helm = {
          values = yamlencode({
            atlantis = {
              serviceAccount = {
                annotations = {
                  "eks.amazonaws.com/role-arn" = aws_iam_role.atlantis.arn
                }
              }

              volumeClaim = {
                enabled          = true
                dataStorage      = "5Gi"
                storageClassName = "gp3"
              }

              ingress = {
                enabled = false # Disable ingress in helm chart - we'll create a dedicated ingress resource
              }

              orgAllowlist = "github.com/${var.github_owner}/*"

              githubApp = {
                id     = tostring(var.github_app_id)
                key    = var.github_app_private_key
                secret = var.github_webhook_secret
              }

              # Atlantis URL for webhooks and external access
              atlantisUrl = var.enable_https ? "https://platform.${var.domain_name}${var.atlantis_path_prefix}" : "http://platform.${var.domain_name}${var.atlantis_path_prefix}"

              # Server-side repository configuration
              # Allow repositories to set apply_requirements in their atlantis.yaml
              repoConfig = <<-EOT
                ---
                repos:
                  - id: /.*/
                    allowed_overrides: [apply_requirements]
              EOT

              # Set timezone to New Zealand (Pacific/Auckland)
              environment = {
                TZ = "Pacific/Auckland"
              }

              extraArgs = [
                "--default-tf-version=${var.default_tf_version}",
                "--write-git-creds"
              ]
            }
          })
        }
      }

      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = "default"
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
          group        = "argoproj.io"
          kind         = "Rollout"
          jsonPointers = ["/status/conditions"]
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
    kubectl_manifest.atlantis_helm_repo,
    aws_iam_role.atlantis,
    aws_iam_role_policy.atlantis_s3
  ]
}

# Ingress resource for Atlantis using shared ALB
resource "kubectl_manifest" "atlantis_ingress" {
  yaml_body = yamlencode({
    apiVersion = "networking.k8s.io/v1"
    kind       = "Ingress"
    metadata = {
      name      = "atlantis"
      namespace = "default"
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

  depends_on = [kubectl_manifest.atlantis_application]
}

# Nginx proxy deployment for path rewriting
# Rewrites /atlantis/* to /* before proxying to Atlantis service
resource "kubectl_manifest" "atlantis_nginx_proxy" {
  yaml_body = yamlencode({
    apiVersion = "apps/v1"
    kind       = "Deployment"
    metadata = {
      name      = "atlantis-nginx-proxy"
      namespace = "default"
      labels = {
        app = "atlantis-nginx-proxy"
      }
    }
    spec = {
      replicas = 1
      selector = {
        matchLabels = {
          app = "atlantis-nginx-proxy"
        }
      }
      template = {
        metadata = {
          labels = {
            app = "atlantis-nginx-proxy"
          }
        }
        spec = {
          containers = [
            {
              name  = "nginx"
              image = "nginx:alpine"
              ports = [
                {
                  containerPort = 80
                  name          = "http"
                }
              ]
              volumeMounts = [
                {
                  name      = "nginx-config"
                  mountPath = "/etc/nginx/conf.d"
                }
              ]
            }
          ]
          volumes = [
            {
              name = "nginx-config"
              configMap = {
                name = "atlantis-nginx-proxy-config"
              }
            }
          ]
        }
      }
    }
  })

  depends_on = [kubectl_manifest.atlantis_application]
}

# Nginx configuration for path rewriting
resource "kubectl_manifest" "atlantis_nginx_config" {
  yaml_body = yamlencode({
    apiVersion = "v1"
    kind       = "ConfigMap"
    metadata = {
      name      = "atlantis-nginx-proxy-config"
      namespace = "default"
    }
    data = {
      "default.conf" = <<-EOT
        server {
          listen 80;

          # Rewrite path prefix to /* before proxying to Atlantis
          location ${var.atlantis_path_prefix}/ {
            rewrite ^${var.atlantis_path_prefix}/(.*)$ /$1 break;
            proxy_pass http://atlantis:80;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header X-Forwarded-Host $host;
            proxy_set_header X-Forwarded-Prefix ${var.atlantis_path_prefix};
          }

          # Redirect path prefix without trailing slash to path with trailing slash
          location = ${var.atlantis_path_prefix} {
            return 301 ${var.atlantis_path_prefix}/;
          }
        }
      EOT
    }
  })

  depends_on = [kubectl_manifest.atlantis_application]
}

# Service for nginx proxy
resource "kubectl_manifest" "atlantis_nginx_service" {
  yaml_body = yamlencode({
    apiVersion = "v1"
    kind       = "Service"
    metadata = {
      name      = "atlantis-nginx-proxy"
      namespace = "default"
      labels = {
        app = "atlantis-nginx-proxy"
      }
    }
    spec = {
      type = "ClusterIP"
      ports = [
        {
          port       = 80
          targetPort = 80
          protocol   = "TCP"
          name       = "http"
        }
      ]
      selector = {
        app = "atlantis-nginx-proxy"
      }
    }
  })

  depends_on = [
    kubectl_manifest.atlantis_nginx_proxy,
    kubectl_manifest.atlantis_nginx_config
  ]
}
