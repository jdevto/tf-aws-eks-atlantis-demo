variable "region" {
  description = "AWS region for resources"
  type        = string
  default     = "ap-southeast-2"
}

variable "cluster_name" {
  type    = string
  default = "test"
}

variable "cluster_version" {
  type    = string
  default = "1.34"
}

variable "enable_ebs_csi_driver" {
  description = "Whether to install AWS EBS CSI Driver"
  type        = bool
  default     = true
}

variable "repo_url" {
  description = "Git repository URL that Argo CD will watch for application manifests."
  type        = string
  default     = "https://github.com/jdevto/tf-aws-eks-atlantis-demo.git"
}

variable "target_revision" {
  description = "Git revision Argo CD should track (branch, tag, or commit SHA)."
  type        = string
  default     = "main"
}

variable "domain_name" {
  description = "Domain name"
  type        = string
}

variable "enable_https" {
  description = "Enable HTTPS for ArgoCD and Atlantis ingress using ACM certificate"
  type        = bool
  default     = false
}

variable "certificate_arn" {
  description = "ACM certificate ARN for HTTPS. Required when enable_https is true."
  type        = string
  default     = ""
}

variable "github_owner" {
  description = "GitHub organization name (or username) where the repository will be created. Set this to your specific organization name."
  type        = string
}

variable "github_app_id" {
  description = <<-EOT
    GitHub App ID for Atlantis authentication.
    Example: 123456

    This is the App ID (not the Installation ID). You can find it in your GitHub App settings.

    IMPORTANT: The GitHub App must be INSTALLED on your organization/repository
    before Atlantis can use it. After creating the GitHub App, you must:
    1. Go to https://github.com/settings/apps
    2. Find your GitHub App and click "Install App"
    3. Select your organization (or specific repositories)
    4. Grant the necessary permissions

    After installation, you must manually add the repository to the GitHub App installation
    via the GitHub UI (managing installations requires organization OWNER role).

    Without installation, Atlantis will fail with: "wrong number of installations, expected 1, found 0"
    EOT
  type        = number
}

variable "github_app_private_key" {
  description = <<-EOT
    GitHub App private key (PEM format) to store in Secrets Manager.
    This is the full PEM-formatted private key, NOT the SHA256 fingerprint.
    The private key is a multi-line string with BEGIN/END markers.
    Example:
    -----BEGIN RSA PRIVATE KEY-----
    MIIEpAIBAAKCAQEA...
    (multiple lines of base64-encoded key data)
    -----END RSA PRIVATE KEY-----

    Note: If you only see "SHA256:???????" that's the fingerprint, not the key.
    Download the actual private key from your GitHub App settings.
    EOT
  type        = string
  sensitive   = true
}

variable "github_webhook_secret" {
  description = <<-EOT
    GitHub webhook secret for Atlantis.
    Example: "your-webhook-secret-string-here"
    EOT
  type        = string
  sensitive   = true
}

variable "demo_repo_name" {
  description = "Name of the demo GitHub repository"
  type        = string
  default     = "atlantis-demo-infra"
}

variable "s3_enable_versioning" {
  description = "Enable versioning for the S3 bucket"
  type        = bool
  default     = true
}

variable "s3_force_destroy" {
  description = "Force destroy the S3 bucket"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "enable_shared_alb" {
  description = "Enable shared ALB functionality. When true, sets up shared ALB for multiple services to use."
  type        = bool
  default     = false
}

variable "aws_auth_map_users" {
  type = list(object({
    userarn  = string
    username = string
    groups   = list(string)
  }))
  default     = []
  description = "List of IAM users to add to aws-auth ConfigMap for Kubernetes access"
}

variable "aws_auth_map_roles" {
  type = list(object({
    rolearn  = string
    username = string
    groups   = list(string)
  }))
  default     = []
  description = "List of IAM roles to add to aws-auth ConfigMap for Kubernetes access"
}
