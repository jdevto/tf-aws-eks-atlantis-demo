variable "cluster_name" {
  type        = string
  description = "Name of the EKS cluster"
}

variable "aws_region" {
  type        = string
  description = "AWS region"
}

variable "subnet_ids" {
  type        = list(string)
  description = "List of subnet IDs for ALB (should be public subnets for internet-facing ALB)"
}

variable "enable_https" {
  type        = bool
  default     = false
  description = "Enable HTTPS for Atlantis ingress using ACM certificate. If true, requires certificate_arn."
}

variable "ssl_redirect" {
  type        = bool
  default     = true
  description = "Redirect HTTP to HTTPS when enable_https is true. If false, both HTTP and HTTPS are accessible."
}

variable "certificate_arn" {
  type        = string
  default     = ""
  description = "ACM certificate ARN for HTTPS. Required when enable_https is true."
}

variable "atlantis_chart_version" {
  type        = string
  default     = "0.3.0"
  description = "Version of the k8sforge/atlantis-chart Helm chart"
}

variable "domain_name" {
  description = "Domain name"
  type        = string
}

variable "github_owner" {
  description = "GitHub organization name (or username) where the repository will be created. Set this to your specific organization name."
  type        = string
}

variable "bitwarden_secrets_namespace" {
  type        = string
  description = "Namespace where Bitwarden secrets are synced (e.g., bitwarden-secrets)"
}

variable "bitwarden_organization_id" {
  type        = string
  description = "Bitwarden organization ID for syncing secrets"
}

variable "bitwarden_auth_token_secret_name" {
  type        = string
  description = "Name of the Kubernetes secret containing Bitwarden access token"
  default     = "bitwarden-auth-token"
}

variable "bitwarden_auth_token_secret_key" {
  type        = string
  description = "Key name in the Bitwarden access token secret"
  default     = "token"
}

# Bitwarden secret IDs - used to sync secrets from Bitwarden to Kubernetes
# These are the only references to secrets in Terraform (no secret values passed)
variable "github_app_id_secret_id" {
  type        = string
  description = "Bitwarden secret ID for GitHub App ID (used to sync secret to Kubernetes)"
}

variable "github_app_private_key_secret_id" {
  type        = string
  description = "Bitwarden secret ID for GitHub App private key (used to sync secret to Kubernetes)"
}

variable "github_webhook_secret_id" {
  type        = string
  description = "Bitwarden secret ID for GitHub webhook secret (used to sync secret to Kubernetes)"
}

# Kubernetes secret names - used to reference secrets synced from Bitwarden
# The secret name is also used as the key name within the secret
variable "github_app_id_secret_name" {
  type        = string
  description = "Name of the Kubernetes secret containing GitHub App ID (synced from Bitwarden). Also used as the key name within the secret."
  default     = "github-app-id"
}

variable "github_app_private_key_secret_name" {
  type        = string
  description = "Name of the Kubernetes secret containing GitHub App private key (synced from Bitwarden). Also used as the key name within the secret."
  default     = "github-app-private-key"
}

variable "github_webhook_secret_name" {
  type        = string
  description = "Name of the Kubernetes secret containing GitHub webhook secret (synced from Bitwarden). Also used as the key name within the secret."
  default     = "github-webhook-secret"
}

variable "default_tf_version" {
  type        = string
  default     = "1.6.0"
  description = "Default Terraform version for Atlantis"
}

variable "state_bucket_name" {
  type        = string
  description = "S3 bucket name for Terraform state (AWS backend). This module is focused on AWS workloads."
}

variable "shared_alb_ingress_group_name" {
  type        = string
  default     = "shared-alb"
  description = "Name of the ingress group for shared ALB. All ingresses with this group name will share the same ALB."
}

variable "argocd_namespace" {
  type        = string
  default     = "argocd"
  description = "Namespace where ArgoCD is installed (used for dependency)"
}

variable "shared_alb_security_group_id" {
  type        = string
  default     = ""
  description = "Security group ID for shared ALB with IP restrictions. Empty if IP restrictions are not configured."
}

variable "atlantis_namespace" {
  type        = string
  default     = "atlantis"
  description = "Kubernetes namespace where Atlantis will be deployed"
}

variable "alb_arn" {
  type        = string
  description = "ARN of the Application Load Balancer"
  default     = ""
}


variable "route53_name" {
  type        = string
  default     = "atlantis"
  description = "Name for the Route53 record (e.g., 'atlantis' creates atlantis.example.com)"
}
