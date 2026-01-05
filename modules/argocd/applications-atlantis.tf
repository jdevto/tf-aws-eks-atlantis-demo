# Register Helm repository for atlantis-charts
resource "kubectl_manifest" "atlantis_helm_repo" {
  yaml_body = yamlencode({
    apiVersion = "v1"
    kind       = "Secret"
    metadata = {
      name      = "atlantis-charts-repo"
      namespace = var.namespace
      labels = {
        "argocd.argoproj.io/secret-type" = "repository"
      }
    }
    stringData = {
      type    = "helm"
      name    = "atlantis-charts"
      url     = "https://k8sforge.github.io/atlantis-charts"
      project = "default"
    }
  })

  depends_on = [helm_release.argocd]
}

# Bootstrap Argo CD Application for atlantis-demo using Helm chart
resource "kubectl_manifest" "atlantis_demo_application" {
  yaml_body = yamlencode({
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "atlantis-demo"
      namespace = var.namespace
      finalizers = [
        "resources-finalizer.argocd.argoproj.io"
      ]
    }
    spec = {
      project = "default"
      source = {
        repoURL        = "https://k8sforge.github.io/atlantis-charts"
        chart          = "atlantis"
        targetRevision = var.atlantis_chart_version
        helm = {
          valueFiles = [
            "values.yaml"
          ]
          # Optional: Add Helm values here or via a values file in your repo
          # values = |
          #   replicaCount: 2
          #   ingress:
          #     enabled: true
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
          group = "argoproj.io"
          kind  = "Rollout"
          jsonPointers = [
            "/status/conditions"
          ]
        },
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
    kubectl_manifest.atlantis_helm_repo
  ]
}
