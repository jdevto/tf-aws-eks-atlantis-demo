# Kubernetes namespace for operator
resource "kubernetes_namespace" "operator" {
  count = var.enable ? 1 : 0

  metadata {
    name = var.operator_namespace
    labels = merge(
      var.tags,
      {
        "app.kubernetes.io/name"       = "bitwarden-secrets-manager-operator"
        "app.kubernetes.io/managed-by" = "terraform"
      }
    )
  }
}

# Kubernetes namespace for secrets
resource "kubernetes_namespace" "secrets" {
  count = var.enable ? 1 : 0

  metadata {
    name = var.namespace
    labels = merge(
      var.tags,
      {
        "app.kubernetes.io/name"       = "bitwarden-secrets"
        "app.kubernetes.io/managed-by" = "terraform"
      }
    )
  }
}

# Kubernetes secret for Bitwarden access token
resource "kubernetes_secret" "auth_token" {
  count = var.enable && var.access_token != null ? 1 : 0

  metadata {
    name      = "bitwarden-auth-token"
    namespace = kubernetes_namespace.secrets[0].metadata[0].name
    labels = merge(
      var.tags,
      {
        "app.kubernetes.io/name"       = "bitwarden-auth-token"
        "app.kubernetes.io/managed-by" = "terraform"
      }
    )
  }

  # Store the raw token value - Kubernetes will base64-encode it automatically
  data = {
    token = var.access_token
  }

  type = "Opaque"
}

# Register Helm repository for Bitwarden Secrets Manager Operator in ArgoCD
resource "kubectl_manifest" "bitwarden_helm_repo" {
  count = var.enable ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "v1"
    kind       = "Secret"
    metadata = {
      name      = "bitwarden-chart-repo"
      namespace = var.argocd_namespace
      labels = {
        "argocd.argoproj.io/secret-type" = "repository"
      }
    }
    stringData = {
      type    = "helm"
      name    = "bitwarden-chart"
      url     = "https://charts.bitwarden.com/"
      project = "default"
    }
  })
}

# ArgoCD Application for Bitwarden Secrets Manager Operator
resource "kubectl_manifest" "bitwarden_application" {
  count = var.enable ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name       = "bitwarden-sm-operator"
      namespace  = var.argocd_namespace
      finalizers = ["resources-finalizer.argocd.argoproj.io"]
    }

    spec = {
      project = "default"

      source = {
        repoURL        = "https://charts.bitwarden.com/"
        chart          = "sm-operator"
        targetRevision = var.operator_helm_version != null ? var.operator_helm_version : "*"

        helm = {
          values = yamlencode({
            settings = {
              bwSecretsManagerRefreshInterval = var.bw_secrets_manager_refresh_interval
            }
            containers = {
              manager = {
                image = var.manager_image_tag != "" ? {
                  tag = var.manager_image_tag
                } : {}
              }
            }
            # Configure replicas for HA (if specified)
            replicas = var.replicas
            # Configure update strategy
            deploymentStrategy = var.update_strategy == "RollingUpdate" ? merge(
              {
                type = "RollingUpdate"
              },
              # Zero-downtime settings when replicas > 1
              var.replicas != null ? (var.replicas > 1 ? {
                rollingUpdate = {
                  maxUnavailable = "0" # Ensure at least one pod is always running
                  maxSurge       = "1" # Allow one extra pod during updates
                }
              } : {}) : {}
              ) : {
              type = "Recreate"
            }
          })
        }
      }

      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = kubernetes_namespace.operator[0].metadata[0].name
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
        }
      ]
    }
  })

  wait = true

  depends_on = [
    kubectl_manifest.bitwarden_helm_repo[0],
    kubernetes_namespace.operator[0]
  ]
}

# =============================================================================
# Bitwarden Secret Sync
# =============================================================================
# Create BitwardenSecret CRDs for each secret in the secrets map
# These will sync secrets from Bitwarden Secrets Manager to Kubernetes

module "secrets" {
  source = "./secrets"
  # Check if auth_token secret exists (instead of checking sensitive var.access_token)
  for_each = var.enable && length(var.secrets) > 0 && length(kubernetes_secret.auth_token) > 0 ? var.secrets : {}

  name            = each.key
  namespace       = kubernetes_namespace.secrets[0].metadata[0].name
  organization_id = var.organization_id
  secret_id       = each.value

  access_token_secret_name = kubernetes_secret.auth_token[0].metadata[0].name
  access_token_secret_key  = "token"

  tags = var.tags

  depends_on = [
    kubernetes_namespace.secrets,
    kubernetes_secret.auth_token
  ]
}
