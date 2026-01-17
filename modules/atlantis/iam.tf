# ============================================================================
# IAM ROLE FOR SERVICE ACCOUNT (IRSA)
# ============================================================================
# Configures AWS IAM role for Atlantis service account using IRSA
# This enables Terraform AWS provider to authenticate automatically via the service account
# No environment variables or access keys needed for AWS authentication

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

# IAM role trust policy for Atlantis service account (IRSA)
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
      values   = ["system:serviceaccount:${var.atlantis_namespace}:atlantis"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(data.aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

# IAM role for Atlantis service account
resource "aws_iam_role" "atlantis" {
  name               = "${var.cluster_name}-atlantis"
  assume_role_policy = data.aws_iam_policy_document.atlantis_assume_role.json
}

# IAM policy for S3 access (for Terraform state backend)
# This module is focused on AWS workloads, so only AWS-specific permissions are configured
# For other providers (e.g., Datadog, GitHub), credentials would be provided via environment variables
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
