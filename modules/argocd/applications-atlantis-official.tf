# Register official Helm repository for atlantis
# NOTE: Repository secret MUST be in ArgoCD namespace for ArgoCD to discover it
resource "kubectl_manifest" "atlantis_official_helm_repo" {
  yaml_body = yamlencode({
    apiVersion = "v1"
    kind       = "Secret"
    metadata = {
      name      = "atlantis-official-repo"
      namespace = var.namespace # Must be in ArgoCD namespace
      labels = {
        "argocd.argoproj.io/secret-type" = "repository"
      }
    }
    stringData = {
      type    = "helm"
      name    = "runatlantis"
      url     = "https://runatlantis.github.io/helm-charts"
      project = "default"
    }
  })

  depends_on = [helm_release.argocd]
}

# Bootstrap Argo CD Application for atlantis-demo using official Helm chart
# NOTE: Application can be in any namespace, but typically in ArgoCD namespace
resource "kubectl_manifest" "atlantis_demo_application_official" {
  yaml_body = yamlencode({
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "atlantis-demo-official"
      namespace = var.namespace # Typically in ArgoCD namespace, but can be "default" if preferred
      finalizers = [
        "resources-finalizer.argocd.argoproj.io"
      ]
    }
    spec = {
      project = "default"
      source = {
        repoURL        = "https://runatlantis.github.io/helm-charts"
        chart          = "atlantis"
        targetRevision = "5.24.1"
        helm = {
          values = <<-EOT
volumeClaim:
  enabled: false
# Optional: Add other Helm values here
# replicaCount: 2
# service:
#   type: ClusterIP
# ingress:
#   enabled: true
#   className: alb
          EOT
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
        syncOptions = [
          "CreateNamespace=true"
        ]
      }
      ignoreDifferences = [
        {
          group = "networking.k8s.io"
          kind  = "Ingress"
          jsonPointers = [
            "/status"
          ]
        }
      ]
    }
  })

  wait = true

  depends_on = [
    helm_release.argocd,
    kubectl_manifest.atlantis_official_helm_repo
  ]
}
