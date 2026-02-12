# Default favicon path
locals {
  default_favicon_path = "${path.module}/templates/favicon.svg"
}

# ConfigMap with HTML content and favicon for landing page
resource "kubernetes_config_map" "landing_page" {
  metadata {
    name      = "landing-page-html"
    namespace = var.namespace
  }

  data = merge(
    {
      "index.html" = templatefile("${path.module}/templates/landing-page.html", {
        services = var.services
      })
    },
    # Add favicon if provided, otherwise use default from templates directory
    {
      "favicon.svg" = var.favicon_path != null ? file("${path.module}/${var.favicon_path}") : file(local.default_favicon_path)
    }
  )
}

# Nginx deployment
resource "kubernetes_deployment" "landing_page" {
  metadata {
    name      = "landing-page"
    namespace = var.namespace
    labels = {
      app = "landing-page"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "landing-page"
      }
    }

    template {
      metadata {
        labels = {
          app = "landing-page"
        }
        annotations = {
          # Force pod restart when ConfigMap changes
          "configmap.kubernetes.io/last-applied-configuration" = sha256(jsonencode(kubernetes_config_map.landing_page.data))
        }
      }

      spec {
        container {
          name  = "nginx"
          image = "nginx:alpine"

          port {
            container_port = 80
          }

          liveness_probe {
            http_get {
              path = "/"
              port = 80
            }
            initial_delay_seconds = 10
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 3
          }

          readiness_probe {
            http_get {
              path = "/"
              port = 80
            }
            initial_delay_seconds = 5
            period_seconds        = 5
            timeout_seconds       = 3
            failure_threshold     = 3
          }

          volume_mount {
            name       = "html"
            mount_path = "/usr/share/nginx/html"
            read_only  = true
          }

          resources {
            requests = {
              cpu    = "10m"
              memory = "16Mi"
            }
            limits = {
              cpu    = "100m"
              memory = "64Mi"
            }
          }
        }

        volume {
          name = "html"
          config_map {
            name = kubernetes_config_map.landing_page.metadata[0].name
          }
        }
      }
    }
  }
}

# Service
resource "kubernetes_service" "landing_page" {
  metadata {
    name      = "landing-page"
    namespace = var.namespace
    labels = {
      app = "landing-page"
    }
  }

  spec {
    selector = {
      app = "landing-page"
    }

    port {
      port        = 80
      target_port = 80
      protocol    = "TCP"
    }

    type = "ClusterIP"
  }
}

# Ingress for root path
resource "kubernetes_ingress_v1" "landing_page" {
  metadata {
    name      = "landing-page"
    namespace = var.namespace
    annotations = merge(
      {
        "alb.ingress.kubernetes.io/scheme"                                = "internet-facing"
        "alb.ingress.kubernetes.io/target-type"                           = "ip"
        "alb.ingress.kubernetes.io/subnets"                               = join(",", var.subnet_ids)
        "alb.ingress.kubernetes.io/backend-protocol"                      = "HTTP"
        "alb.ingress.kubernetes.io/healthcheck-path"                      = "/"
        "alb.ingress.kubernetes.io/healthcheck-port"                      = "traffic-port"
        "alb.ingress.kubernetes.io/healthcheck-protocol"                  = "HTTP"
        "alb.ingress.kubernetes.io/healthcheck-interval-seconds"          = "30"
        "alb.ingress.kubernetes.io/healthcheck-timeout-seconds"           = "10"
        "alb.ingress.kubernetes.io/healthcheck-healthy-threshold-count"   = "2"
        "alb.ingress.kubernetes.io/healthcheck-unhealthy-threshold-count" = "5"
        "alb.ingress.kubernetes.io/group.name"                            = var.shared_alb_ingress_group_name
        # Set order to ensure root path is handled correctly
        "alb.ingress.kubernetes.io/order" = "1"
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

  spec {
    ingress_class_name = "alb"

    rule {
      http {
        # Favicon path
        path {
          path      = "/favicon.svg"
          path_type = "Exact"
          backend {
            service {
              name = kubernetes_service.landing_page.metadata[0].name
              port {
                number = 80
              }
            }
          }
        }
        # Root path (must be last to avoid conflicts)
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service.landing_page.metadata[0].name
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }
}

# Get ALB details. Count uses create_route53 (static) so plan can succeed; precondition ensures alb_arn is set at apply.
data "aws_lb" "shared_alb_details" {
  count = var.create_route53 ? 1 : 0

  arn = var.alb_arn

  lifecycle {
    precondition {
      condition     = !var.create_route53 || var.alb_arn != ""
      error_message = "When create_route53 is true, alb_arn must be set. Run: terraform apply -target=module.shared_alb (ensure AWS LB controller is installed so ALB exists), then terraform apply again."
    }
  }
}

# Route53 record for landing page
module "route53" {
  source = "../route53"

  count = var.create_route53 ? 1 : 0

  name         = var.route53_name
  domain_name  = var.domain_name
  alb_dns_name = data.aws_lb.shared_alb_details[0].dns_name
  alb_zone_id  = data.aws_lb.shared_alb_details[0].zone_id

  depends_on = [
    kubernetes_ingress_v1.landing_page
  ]
}
