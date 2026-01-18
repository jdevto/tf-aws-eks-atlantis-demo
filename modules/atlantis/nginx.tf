# ============================================================================
# NGINX PROXY
# ============================================================================
# Nginx proxy deployment for path rewriting
# Rewrites /atlantis/* to /* before proxying to Atlantis service
# This is a workaround until the Atlantis Helm chart supports native path prefix configuration

# Nginx proxy deployment
resource "kubectl_manifest" "atlantis_nginx_proxy" {
  yaml_body = yamlencode({
    apiVersion = "apps/v1"
    kind       = "Deployment"
    metadata = {
      name      = "atlantis-nginx-proxy"
      namespace = var.atlantis_namespace
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

  depends_on = [
    kubernetes_namespace.atlantis,
    kubectl_manifest.atlantis_application,
    kubectl_manifest.atlantis_nginx_config
  ]
}

# Nginx configuration for path rewriting
resource "kubectl_manifest" "atlantis_nginx_config" {
  yaml_body = yamlencode({
    apiVersion = "v1"
    kind       = "ConfigMap"
    metadata = {
      name      = "atlantis-nginx-proxy-config"
      namespace = var.atlantis_namespace
    }
    data = {
      "default.conf" = <<-EOT
        resolver kube-dns.kube-system.svc.cluster.local valid=10s;

        server {
          listen 80;

          # Rewrite path prefix to /* before proxying to Atlantis
          location ${var.atlantis_path_prefix}/ {
            set $atlantis_upstream "atlantis.${var.atlantis_namespace}.svc.cluster.local:80";
            rewrite ^${var.atlantis_path_prefix}/(.*)$ /$1 break;
            proxy_pass http://$atlantis_upstream;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header X-Forwarded-Host $host;
            proxy_set_header X-Forwarded-Prefix ${var.atlantis_path_prefix};
            proxy_connect_timeout 60s;
            proxy_send_timeout 60s;
            proxy_read_timeout 60s;
          }

          # Redirect path prefix without trailing slash to path with trailing slash
          location = ${var.atlantis_path_prefix} {
            return 301 ${var.atlantis_path_prefix}/;
          }
        }
      EOT
    }
  })

  depends_on = [
    kubernetes_namespace.atlantis,
    kubectl_manifest.atlantis_application
  ]
}

# Service for nginx proxy
resource "kubectl_manifest" "atlantis_nginx_service" {
  yaml_body = yamlencode({
    apiVersion = "v1"
    kind       = "Service"
    metadata = {
      name      = "atlantis-nginx-proxy"
      namespace = var.atlantis_namespace
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
    kubernetes_namespace.atlantis,
    kubectl_manifest.atlantis_nginx_proxy,
    kubectl_manifest.atlantis_nginx_config
  ]
}
