# ============================================================================
# ATLANTIS DEPLOYMENT
# ============================================================================
# Deploys Atlantis via ArgoCD using the k8sforge/atlantis-chart Helm chart
# This file contains both:
# 1. ArgoCD Application resource (deployment mechanism)
# 2. Atlantis server configuration (repoConfig, workflows, Helm values)
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
                      key  = var.github_app_id_secret_name
                    }
                  }
                },
                {
                  name = "ATLANTIS_GH_APP_KEY"
                  valueFrom = {
                    secretKeyRef = {
                      name = var.github_app_private_key_secret_name
                      key  = var.github_app_private_key_secret_name
                    }
                  }
                },
                {
                  name = "ATLANTIS_GH_WEBHOOK_SECRET"
                  valueFrom = {
                    secretKeyRef = {
                      name = var.github_webhook_secret_name
                      key  = var.github_webhook_secret_name
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
              # Defines custom workflows and repo-specific rules for team-based access control
              repoConfig = <<-EOT
                ---
                repos:
                  # terraform-aws repository: custom workflows with team-based access
                  # Using repo-specific workflow names to avoid conflicts with other repos
                  - id: /.*terraform-aws.*/
                    allowed_workflows: [atlantis-terraform-aws-dev-workflow, atlantis-terraform-aws-prod-workflow]
                    allowed_overrides: [apply_requirements]
                    # Default apply requirements (can be overridden per project)
                    apply_requirements: [approved]

                  # Default fallback for other repos (extensibility)
                  # Future repos (terraform-github, terraform-datadog) can define their own workflows
                  - id: /.*/
                    allowed_overrides: [apply_requirements, workflow]
                    apply_requirements: [approved]
                    allow_custom_workflows: true

                # Custom workflows - repo-specific naming to avoid conflicts
                # Format: {repo-name}-{environment}-workflow
                # Note: No workspace commands - directories provide separation
                workflows:
                  atlantis-terraform-aws-dev-workflow:
                    plan:
                      steps:
                        - init
                        - plan  # Runs in dev/ directory context
                    apply:
                      steps:
                        - init
                        - apply  # Runs in dev/ directory context

                  atlantis-terraform-aws-prod-workflow:
                    plan:
                      steps:
                        - init
                        - plan  # Runs in prod/ directory context
                    apply:
                      steps:
                        - init
                        # Team membership check: Only platform team can apply to prod
                        # DevOps can plan but not apply (this step will block them)
                        - run: |
                            USER="$$ATLANTIS_COMMENT_USER"
                            REPO="$$ATLANTIS_REPO"
                            ORG="${var.github_owner}"

                            # Check if user is in platform team via GitHub API
                            # This requires GitHub App to have org:read permission
                            # Using gh CLI if available, otherwise curl with GitHub API
                            if command -v gh >/dev/null 2>&1; then
                              if ! gh api "/orgs/$${ORG}/teams/platform/members/$${USER}" --jq .login 2>/dev/null; then
                                echo "Error: Only @platform team members can apply to production"
                                echo "User $${USER} is not a member of the @platform team"
                                exit 1
                              fi
                              echo "User $${USER} verified as @platform team member"
                            else
                              # Fallback: Use curl with GitHub API (requires token setup)
                              echo "Warning: gh CLI not available, team check may not work"
                              echo "Error: Only @platform team members can apply to production"
                              exit 1
                            fi
                        - apply  # Runs in prod/ directory context
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
