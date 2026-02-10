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
  default = "1.35"
}

variable "access_entries" {
  description = "Map of access entries to add to the cluster"
  type = map(object({
    kubernetes_groups = optional(list(string))
    principal_arn     = string
    type              = optional(string, "STANDARD")
    user_name         = optional(string)
    tags              = optional(map(string), {})
    policy_associations = optional(map(object({
      policy_arn = string
      access_scope = object({
        namespaces = optional(list(string))
        type       = string
      })
    })), {})
  }))
  default = {}
}

variable "enable_aws_load_balancer_controller" {
  description = "Whether to create IAM role for AWS Load Balancer Controller (IRSA)"
  type        = bool
  default     = true
}

# variable "enable_ebs_csi_driver" {
#   description = "Whether to install AWS EBS CSI Driver"
#   type        = bool
#   default     = true
# }

variable "bitwarden_organization_id" {
  description = "Bitwarden organization ID"
  type        = string
  default     = null
}

variable "bitwarden_access_token" {
  description = "Bitwarden machine account access token (sensitive)"
  type        = string
  sensitive   = true
  default     = null
}

variable "bitwarden_secrets" {
  description = "Map of Bitwarden secrets to sync. Key is the secret name, value is the secret_id. Key name in Kubernetes secret will be auto-generated from the secret name."
  type        = map(string) # Map of secret_name -> secret_id
  default     = {}
}

variable "bitwarden_reader_secret_names" {
  description = "List of Kubernetes secret names for the bitwarden-reader app to display. If null, will use all secrets from bitwarden_secrets."
  type        = list(string)
  default     = null
}

variable "bitwarden_operator_helm_version" {
  description = "Version of the Bitwarden Secrets Manager Operator Helm chart. If null, uses latest."
  type        = string
  default     = null
}

variable "bitwarden_bw_secrets_manager_refresh_interval" {
  description = "Refresh interval for Bitwarden Secrets Manager in seconds. Minimum value is 180. Default is 300 (5 minutes)."
  type        = number
  default     = 300
}

variable "bitwarden_manager_image_tag" {
  description = "Tag for the Bitwarden Secrets Manager Operator manager container image. If empty string (default), will use the Chart's AppVersion. Set to override with a specific image tag."
  type        = string
  default     = ""
}

variable "bitwarden_replicas" {
  description = "Number of replicas for the Bitwarden operator. For HA, set to 2+ (with leader election, only one will be active). If null, uses chart default."
  type        = number
  default     = null
}

variable "bitwarden_update_strategy" {
  description = "Deployment update strategy for Bitwarden operator. Options: RollingUpdate (default) or Recreate. RollingUpdate recommended for HA."
  type        = string
  default     = "RollingUpdate"
  validation {
    condition     = contains(["RollingUpdate", "Recreate"], var.bitwarden_update_strategy)
    error_message = "bitwarden_update_strategy must be either RollingUpdate or Recreate"
  }
}

variable "bitwarden_enable" {
  description = "Enable/disable the Bitwarden Secrets Manager module"
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

variable "github_webhook_secret" {
  description = <<-EOT
    GitHub webhook secret for Atlantis.
    Example: "your-webhook-secret-string-here"
    EOT
  type        = string
  sensitive   = true
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

# variable "enable_shared_alb" {
#   description = "Enable shared ALB functionality. When true, sets up shared ALB for multiple services to use."
#   type        = bool
#   default     = false
# }

# variable "cluster_admin_arns" {
#   description = "List of IAM user/role ARNs to grant cluster admin access via EKS access entries"
#   type        = list(string)
#   default     = []
# }

# variable "shared_alb_allowed_ips" {
#   type        = list(string)
#   default     = ["0.0.0.0/0"]
#   description = "List of CIDR blocks allowed to access the shared ALB. If empty, all IPs are allowed. Example: [\"1.2.3.4/32\", \"10.0.0.0/8\"]"
# }

# variable "enable_pod_identity_agent" {
#   description = "Whether to enable the EKS Pod Identity Agent addon"
#   type        = bool
#   default     = true
# }

# variable "cluster_authentication_mode" {
#   description = "Authentication mode for the EKS cluster. Valid values: CONFIG_MAP, API, API_AND_CONFIG_MAP. Defaults to API_AND_CONFIG_MAP when capabilities are enabled, otherwise CONFIG_MAP."
#   type        = string
#   default     = "API_AND_CONFIG_MAP"

#   validation {
#     condition     = contains(["CONFIG_MAP", "API", "API_AND_CONFIG_MAP"], var.cluster_authentication_mode)
#     error_message = "cluster_authentication_mode must be one of: CONFIG_MAP, API, API_AND_CONFIG_MAP"
#   }
# }
