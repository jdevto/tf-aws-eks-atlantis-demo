# ============================================================================
# ARGOCD APPLICATION
# ============================================================================
# Deploys Atlantis via ArgoCD using the k8sforge/atlantis-chart Helm chart
# This module is focused on AWS workloads and uses IRSA for AWS credentials

# Register Helm repository for atlantis-chart in ArgoCD
resource "kubectl_manifest" "atlantis_helm_repo" {
  yaml_body = yamlencode({
    apiVersion = "v1"
    kind       = "Secret"
    metadata = {
      name      = "atlantis-chart-repo"
      namespace = var.argocd_namespace
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
}

# ArgoCD Application for Atlantis
# Note: We do NOT read secret values in Terraform to avoid exposing them in state/logs
# Instead, we configure Atlantis to read secrets directly from Kubernetes secrets via environment variables
# This way, Terraform only references secret names, not values
resource "kubectl_manifest" "atlantis_application" {
  yaml_body = yamlencode({
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name       = "atlantis"
      namespace  = var.argocd_namespace
      finalizers = ["resources-finalizer.argocd.argoproj.io"]
    }

    spec = {
      project = "default"

      source = {
        repoURL        = "https://k8sforge.github.io/atlantis-chart"
        chart          = "atlantis"
        targetRevision = var.atlantis_chart_version

        helm = {
          values = yamlencode({
            # GitHub App Secrets Support (wrapper chart feature)
            # DISABLED: We're using environmentRaw with secretKeyRef directly instead
            # The wrapper chart's githubAppSecrets uses environmentSecrets with $keyname syntax
            # which conflicts with our direct secretKeyRef approach
            githubAppSecrets = {
              enabled = false
            }

            atlantis = {
              # Service Account with IRSA annotation for AWS credentials
              # AWS provider credentials are automatically available via IRSA
              # No environment variables needed for AWS authentication
              serviceAccount = {
                annotations = {
                  "eks.amazonaws.com/role-arn" = aws_iam_role.atlantis.arn
                }
              }

              # Persistent storage for Terraform state and workspace data
              volumeClaim = {
                enabled          = true
                dataStorage      = "5Gi"
                storageClassName = "gp3"
              }

              # Ingress is disabled in Helm chart - we create a dedicated ingress resource
              ingress = {
                enabled = false
              }

              # GitHub organization allowlist
              orgAllowlist = "github.com/${var.github_owner}/*"

              # GitHub App credentials for Atlantis (webhooks, PR comments)
              # Injected via environmentRaw using secretKeyRef from Kubernetes secrets
              # These secrets are synced from Bitwarden (see bitwarden.tf)
              environmentRaw = [
                {
                  name = "ATLANTIS_GH_APP_ID"
                  valueFrom = {
                    secretKeyRef = {
                      name = var.github_app_id_secret_name
                      key  = var.github_app_id_secret_key
                    }
                  }
                },
                {
                  name = "ATLANTIS_GH_APP_KEY"
                  valueFrom = {
                    secretKeyRef = {
                      name = var.github_app_private_key_secret_name
                      key  = var.github_app_private_key_secret_key
                    }
                  }
                },
                {
                  name = "ATLANTIS_GH_WEBHOOK_SECRET"
                  valueFrom = {
                    secretKeyRef = {
                      name = var.github_webhook_secret_name
                      key  = var.github_webhook_secret_key
                    }
                  }
                }
              ]

              # Non-secret environment variables
              environment = {
                TZ = "Pacific/Auckland"
              }

              # Atlantis URL for webhooks and external access
              atlantisUrl = var.enable_https ? "https://platform.${var.domain_name}${var.atlantis_path_prefix}" : "http://platform.${var.domain_name}${var.atlantis_path_prefix}"

              # Server-side repository configuration
              # Allow repositories to set apply_requirements in their atlantis.yaml
              repoConfig = <<-EOT
                ---
                repos:
                  - id: /.*/
                    allowed_overrides: [apply_requirements]
              EOT

              extraArgs = [
                "--default-tf-version=${var.default_tf_version}",
                "--write-git-creds"
              ]
            }
          })
        }
      }

      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = var.atlantis_namespace
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
          group        = "networking.k8s.io"
          kind         = "Ingress"
          jsonPointers = ["/status"]
        }
      ]
    }
  })

  wait = true

  depends_on = [
    kubectl_manifest.atlantis_helm_repo,
    aws_iam_role.atlantis,
    aws_iam_role_policy.atlantis_s3,
    kubernetes_namespace.atlantis
  ]
}
