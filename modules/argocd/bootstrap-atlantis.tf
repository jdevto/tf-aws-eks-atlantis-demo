# Get EKS cluster for OIDC provider
data "aws_eks_cluster" "this" {
  name = var.cluster_name
}

data "tls_certificate" "eks" {
  url = data.aws_eks_cluster.this.identity[0].oidc[0].issuer
}

data "aws_iam_openid_connect_provider" "eks" {
  url = data.aws_eks_cluster.this.identity[0].oidc[0].issuer
}

# Get current AWS account ID
data "aws_caller_identity" "current" {}

# IAM role for Atlantis service account (IRSA)
data "aws_iam_policy_document" "atlantis_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.eks.arn]
    }

    actions = ["sts:AssumeRoleWithWebIdentity"]

    condition {
      test     = "StringEquals"
      variable = "${replace(data.aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", "")}:sub"
      values   = ["system:serviceaccount:default:atlantis"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(data.aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "atlantis" {
  name               = "${var.cluster_name}-atlantis"
  assume_role_policy = data.aws_iam_policy_document.atlantis_assume_role.json
}

# Policy for S3 access (for Terraform state)
resource "aws_iam_role_policy" "atlantis_s3" {
  name = "${var.cluster_name}-atlantis-s3-policy"
  role = aws_iam_role.atlantis.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation",
          "s3:GetBucketVersioning"
        ]
        Resource = "arn:aws:s3:::${var.state_bucket_name}"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:GetObjectVersion"
        ]
        Resource = "arn:aws:s3:::${var.state_bucket_name}/*"
      }
    ]
  })
}

# Policy for DynamoDB access (for state locking)
resource "aws_iam_role_policy" "atlantis_dynamodb" {
  name = "${var.cluster_name}-atlantis-dynamodb-policy"
  role = aws_iam_role.atlantis.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:DeleteItem",
          "dynamodb:UpdateItem"
        ]
        Resource = "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/${var.state_lock_table}"
      }
    ]
  })
}

# Register Helm repository for atlantis-chart
resource "kubectl_manifest" "atlantis_helm_repo" {
  yaml_body = yamlencode({
    apiVersion = "v1"
    kind       = "Secret"
    metadata = {
      name      = "atlantis-chart-repo"
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

# Bootstrap Argo CD Application for atlantis using Helm chart
resource "kubectl_manifest" "atlantis_application" {
  yaml_body = yamlencode({
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name       = "atlantis"
      namespace  = var.namespace
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
            atlantis = {
              serviceAccount = {
                annotations = {
                  "eks.amazonaws.com/role-arn" = aws_iam_role.atlantis.arn
                }
              }

              volumeClaim = {
                enabled          = true
                dataStorage      = "5Gi"
                storageClassName = "gp3"
              }

              ingress = {
                enabled          = true
                ingressClassName = "alb"
                annotations = merge(
                  {
                    "alb.ingress.kubernetes.io/scheme"           = "internet-facing"
                    "alb.ingress.kubernetes.io/target-type"      = "ip"
                    "alb.ingress.kubernetes.io/subnets"          = join(",", var.subnet_ids)
                    "alb.ingress.kubernetes.io/backend-protocol" = "HTTP"
                    "alb.ingress.kubernetes.io/healthcheck-path" = "/healthz"
                  },
                  # HTTP-only configuration
                  !var.enable_https ? {
                    "alb.ingress.kubernetes.io/listen-ports" = "[{\"HTTP\": 80}]"
                  } : {},
                  # HTTPS configuration (base)
                  var.enable_https ? {
                    "alb.ingress.kubernetes.io/listen-ports"    = "[{\"HTTP\": 80}, {\"HTTPS\": 443}]"
                    "alb.ingress.kubernetes.io/certificate-arn" = var.certificate_arn
                    "alb.ingress.kubernetes.io/ssl-policy"      = "ELBSecurityPolicy-TLS13-1-2-2021-06"
                  } : {},
                  # HTTPS redirect (optional)
                  var.enable_https && var.ssl_redirect ? {
                    "alb.ingress.kubernetes.io/ssl-redirect" = "443"
                  } : {}
                )
                host = ""
              }

              orgAllowlist = "github.com/${var.github_owner}/*"

              githubApp = {
                id     = tostring(var.github_app_id)
                key    = var.github_app_private_key
                secret = var.github_webhook_secret
              }

              atlantisUrl = var.enable_https ? "https://atlantis.${var.domain_name}" : "http://atlantis.${var.domain_name}"

              extraArgs = [
                "--default-tf-version=${var.default_tf_version}",
                "--write-git-creds",
                "--allow-repo-config"
              ]

              env = [
                {
                  name  = "AWS_REGION"
                  value = var.aws_region
                },
                {
                  name  = "AWS_DEFAULT_REGION"
                  value = var.aws_region
                }
              ]
            }
          })
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
        syncOptions = ["CreateNamespace=true"]
      }

      ignoreDifferences = [
        {
          group        = "argoproj.io"
          kind         = "Rollout"
          jsonPointers = ["/status/conditions"]
        },
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
    helm_release.argocd,
    kubectl_manifest.atlantis_helm_repo,
    aws_iam_role.atlantis,
    aws_iam_role_policy.atlantis_s3,
    aws_iam_role_policy.atlantis_dynamodb
  ]
}

# Get the ALB by its DNS name
data "aws_lb" "atlantis" {
  tags = {
    "elbv2.k8s.aws/cluster" = var.cluster_name
    "ingress.k8s.aws/stack" = "default/atlantis"
  }

  depends_on = [helm_release.argocd]
}
