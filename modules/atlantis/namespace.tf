# ============================================================================
# NAMESPACE
# ============================================================================
# Creates the Kubernetes namespace for Atlantis deployment

resource "kubernetes_namespace" "atlantis" {
  metadata {
    name = var.atlantis_namespace
    labels = {
      "app.kubernetes.io/name"       = "atlantis"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}
