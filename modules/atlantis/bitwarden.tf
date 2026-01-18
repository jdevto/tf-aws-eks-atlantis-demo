# ============================================================================
# BITWARDEN SECRETS SYNC
# ============================================================================
# Syncs GitHub App credentials from Bitwarden Secrets Manager to the Atlantis namespace
# This allows Atlantis to authenticate with GitHub for webhooks and PR comments

# Read Bitwarden auth token from bitwarden-secrets namespace
# Following Bitwarden's standard pattern: create auth token secret in each namespace that needs syncing
data "kubernetes_secret" "auth_token_source" {
  metadata {
    name      = var.bitwarden_auth_token_secret_name
    namespace = var.bitwarden_secrets_namespace
  }
}

# Create auth token secret in atlantis namespace (standard Bitwarden pattern)
# Each namespace that uses BitwardenSecret CRDs needs its own auth token secret
resource "kubernetes_secret" "auth_token" {
  metadata {
    name      = var.bitwarden_auth_token_secret_name
    namespace = var.atlantis_namespace
    labels = {
      "app.kubernetes.io/name"       = "bitwarden-auth-token"
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/component"  = "atlantis"
    }
  }
  data = data.kubernetes_secret.auth_token_source.data
  type = "Opaque"

  depends_on = [
    kubernetes_namespace.atlantis,
    kubectl_manifest.atlantis_application
  ]
}

# Sync GitHub App secrets from Bitwarden to the Atlantis namespace
# This allows Atlantis to reference secrets via secretKeyRef (which doesn't support cross-namespace)
# We create BitwardenSecret CRDs that sync the same secrets to the Atlantis namespace
locals {
  github_secrets = {
    (var.github_app_id_secret_name)          = var.github_app_id_secret_id
    (var.github_app_private_key_secret_name) = var.github_app_private_key_secret_id
    (var.github_webhook_secret_name)         = var.github_webhook_secret_id
  }
}

resource "kubectl_manifest" "atlantis_github_secrets" {
  for_each = local.github_secrets

  yaml_body = yamlencode({
    apiVersion = "k8s.bitwarden.com/v1"
    kind       = "BitwardenSecret"
    metadata = {
      name      = each.key
      namespace = var.atlantis_namespace
      labels = {
        "app.kubernetes.io/name"       = "atlantis-github-secret"
        "app.kubernetes.io/managed-by" = "terraform"
        "app.kubernetes.io/component"  = "atlantis"
      }
    }
    spec = {
      organizationId = var.bitwarden_organization_id
      secretName     = each.key
      authToken = {
        secretName = var.bitwarden_auth_token_secret_name
        secretKey  = var.bitwarden_auth_token_secret_key
        # Note: The auth token secret must be in the same namespace as this BitwardenSecret CRD
        # Following Bitwarden's standard pattern: auth token secret is created in atlantis namespace
      }
      map = [{
        bwSecretId    = each.value
        secretKeyName = each.key
      }]
    }
  })

  depends_on = [
    kubernetes_namespace.atlantis,
    kubectl_manifest.atlantis_application,
    kubernetes_secret.auth_token
  ]
}
