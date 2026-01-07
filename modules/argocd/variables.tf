variable "namespace" {
  type    = string
  default = "argocd"
}

variable "chart_version" {
  type        = string
  default     = "0.1.4"
  description = "Version of the k8sforge/argocd-chart Helm chart"
}

variable "aws_region" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "subnet_ids" {
  type        = list(string)
  description = "List of subnet IDs for ALB (should be public subnets for internet-facing ALB)"
}

variable "enable_https" {
  type        = bool
  default     = false
  description = "Enable HTTPS for ArgoCD ingress using ACM certificate. If true, requires certificate_arn."
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
  description = "Version of the k8sforge/atlantis-charts Helm chart"
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
}

variable "github_webhook_secret" {
  type        = string
  description = "GitHub webhook secret for Atlantis authentication"
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

variable "state_lock_table" {
  type        = string
  description = "DynamoDB table name for Terraform state locking"
}
