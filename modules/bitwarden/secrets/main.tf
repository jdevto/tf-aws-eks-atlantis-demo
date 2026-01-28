# BitwardenSecret CRD - syncs a single secret from Bitwarden to Kubernetes
resource "kubectl_manifest" "bitwarden_secret" {
  yaml_body = yamlencode({
    apiVersion = "k8s.bitwarden.com/v1"
    kind       = "BitwardenSecret"
    metadata = {
      name      = var.name
      namespace = var.namespace
      labels = merge(
        var.tags,
        {
          "app.kubernetes.io/name"       = "bitwarden-secret"
          "app.kubernetes.io/managed-by" = "terraform"
        }
      )
    }
    spec = {
      organizationId = var.organization_id
      secretName     = var.name
      authToken = {
        secretName = var.access_token_secret_name
        secretKey  = var.access_token_secret_key
      }
      map = [{
        bwSecretId    = var.secret_id
        secretKeyName = var.key_name != null ? var.key_name : var.name
      }]
    }
  })
}
