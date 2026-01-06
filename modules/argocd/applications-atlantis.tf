# Register Helm repository for atlantis-chart
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
      name    = "atlantis-chart"
      url     = "https://k8sforge.github.io/atlantis-chart"
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
        repoURL        = "https://k8sforge.github.io/atlantis-chart"
        chart          = "atlantis"
        targetRevision = "0.1.6"
        helm = {
          valueFiles = [
            "values.yaml"
          ]
          skipSchemaValidation = true # Bypass v0.1.6 schema issues
          values               = <<-EOT
                  # v0.1.6 configuration with enhanced features
                  replicaCount: 1

                  # Enhanced persistence (v0.1.6 feature)
                  persistence:
                    enabled: true
                    ebs:
                      storageClass: "gp3"
                      size: "5Gi"

                  # All Atlantis configuration under 'atlantis' key
                  atlantis:
                    # Repository allowlist
                    orgAllowlist: "github.com/*"

                    # Environment variables
                    environment:
                      ATLANTIS_GH_USER: "placeholder-user"
                      ATLANTIS_GH_TOKEN: "placeholder-token"
                      ATLANTIS_DISABLE_APPLY_ALL: "true"

                    # Ingress configuration
                    ingress:
                      enabled: true
                      ingressClassName: "alb"
                      annotations:
                        alb.ingress.kubernetes.io/scheme: internet-facing
                        alb.ingress.kubernetes.io/target-type: ip
                        alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}]'
                        alb.ingress.kubernetes.io/subnets: ${join(",", var.subnet_ids)}

                    # Data storage (string format for v0.1.6)
                    dataStorage: "5Gi"

                    # Replica count for official chart
                    replicaCount: 1
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
