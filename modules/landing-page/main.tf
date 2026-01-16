# ConfigMap with HTML content for landing page
resource "kubernetes_config_map" "landing_page" {
  metadata {
    name      = "landing-page-html"
    namespace = var.namespace
  }

  data = {
    "index.html" = <<-HTML
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Platform Services</title>
      <style>
        * {
          margin: 0;
          padding: 0;
          box-sizing: border-box;
        }
        body {
          font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
          background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
          min-height: 100vh;
          display: flex;
          align-items: center;
          justify-content: center;
          padding: 20px;
        }
        .container {
          max-width: 900px;
          width: 100%;
          background: white;
          border-radius: 12px;
          box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
          overflow: hidden;
        }
        .header {
          background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
          color: white;
          padding: 40px;
          text-align: center;
        }
        .header h1 {
          font-size: 2.5em;
          margin-bottom: 10px;
        }
        .header p {
          font-size: 1.1em;
          opacity: 0.9;
        }
        .services {
          padding: 40px;
        }
        .service {
          margin: 20px 0;
          padding: 25px;
          border: 2px solid #e0e0e0;
          border-radius: 8px;
          transition: all 0.3s ease;
          background: #f9f9f9;
        }
        .service:hover {
          border-color: #667eea;
          box-shadow: 0 4px 12px rgba(102, 126, 234, 0.2);
          transform: translateY(-2px);
        }
        .service h2 {
          color: #667eea;
          margin-bottom: 10px;
          font-size: 1.5em;
        }
        .service a {
          color: #667eea;
          text-decoration: none;
          font-weight: 600;
        }
        .service a:hover {
          text-decoration: underline;
        }
        .service p {
          color: #666;
          line-height: 1.6;
          margin-top: 8px;
        }
        .footer {
          text-align: center;
          padding: 20px;
          color: #999;
          font-size: 0.9em;
        }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="header">
          <h1>🚀 Platform Services</h1>
          <p>Welcome to the platform infrastructure portal</p>
        </div>
        <div class="services">
          <div class="service">
            <h2><a href="/argocd">ArgoCD</a></h2>
            <p>GitOps continuous delivery tool for Kubernetes. Manage your applications declaratively with automated sync and rollback capabilities.</p>
          </div>
          <div class="service">
            <h2><a href="/atlantis">Atlantis</a></h2>
            <p>Terraform automation via pull requests. Review and apply infrastructure changes safely through your Git workflow.</p>
          </div>
        </div>
        <div class="footer">
          <p>Platform Infrastructure Portal</p>
        </div>
      </div>
    </body>
    </html>
    HTML
  }
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
      }

      spec {
        container {
          name  = "nginx"
          image = "nginx:alpine"

          port {
            container_port = 80
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
        "alb.ingress.kubernetes.io/scheme"           = "internet-facing"
        "alb.ingress.kubernetes.io/target-type"      = "ip"
        "alb.ingress.kubernetes.io/subnets"          = join(",", var.subnet_ids)
        "alb.ingress.kubernetes.io/backend-protocol" = "HTTP"
        "alb.ingress.kubernetes.io/group.name"       = var.shared_alb_ingress_group_name
        # Set order to ensure root path is handled correctly
        "alb.ingress.kubernetes.io/order" = "1"
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
          path      = "/"
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
      }
    }
  }
}
