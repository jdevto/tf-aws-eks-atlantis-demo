variable "namespace" {
  type        = string
  default     = "argocd"
  description = "Kubernetes namespace where ArgoCD is installed (for registering the Helm repo)"
}

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
  default     = "0.1.9"
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

variable "github_app_id" {
  type        = number
  description = "GitHub App ID for Atlantis authentication"
}

variable "github_app_private_key" {
  type        = string
  description = "GitHub App private key (PEM) for Atlantis authentication"
  sensitive   = true
}

variable "github_webhook_secret" {
  type        = string
  description = "GitHub webhook secret for Atlantis authentication"
  sensitive   = true
}

variable "default_tf_version" {
  type        = string
  default     = "1.6.0"
  description = "Default Terraform version for Atlantis"
}

variable "state_bucket_name" {
  type        = string
  description = "S3 bucket name for Terraform state"
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
