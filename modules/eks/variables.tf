variable "cluster_name" {
  type = string
}

variable "cluster_version" {
  type = string
}

variable "subnet_ids" {
  description = "Subnet IDs for EKS cluster control plane (should include both public and private)"
  type        = list(string)
}

variable "node_subnet_ids" {
  description = "Subnet IDs for EKS node groups (should be private subnets only for security)"
  type        = list(string)
  default     = null
}

variable "endpoint_public_access" {
  description = "Whether the Amazon EKS public API server endpoint is enabled"
  type        = bool
  default     = true
}

variable "public_access_cidrs" {
  description = "List of CIDR blocks that can access the Amazon EKS public API server endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "enabled_cluster_log_types" {
  description = "List of control plane logging types to enable"
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

variable "node_instance_types" {
  type    = list(string)
  default = ["t3.medium"]
}

variable "node_desired_size" {
  type    = number
  default = 2
}

variable "node_min_size" {
  type    = number
  default = 1
}

variable "node_max_size" {
  type    = number
  default = 3
}

variable "node_disk_size" {
  description = "Disk size in GiB for worker nodes"
  type        = number
  default     = 20
}

variable "node_update_max_unavailable" {
  description = "Maximum number of nodes unavailable during update"
  type        = number
  default     = 1
}

variable "node_remote_access_enabled" {
  description = "Whether to enable remote access to nodes"
  type        = bool
  default     = false
}

variable "node_remote_access_ssh_key" {
  description = "EC2 SSH key name for remote access"
  type        = string
  default     = null
}

variable "node_remote_access_security_groups" {
  description = "List of security group IDs for remote access"
  type        = list(string)
  default     = []
}

variable "node_labels" {
  description = "Key-value map of Kubernetes labels to apply to nodes"
  type        = map(string)
  default     = {}
}

variable "vpc_id" {
  description = "VPC ID where the cluster is deployed"
  type        = string
}

variable "enable_aws_lb_controller" {
  description = "Whether to install AWS Load Balancer Controller"
  type        = bool
  default     = true
}

variable "aws_lb_controller_helm_version" {
  description = "Version of the AWS Load Balancer Controller Helm chart"
  type        = string
  default     = "1.7.2"
}

variable "enable_ebs_csi_driver" {
  description = "Whether to install AWS EBS CSI Driver"
  type        = bool
  default     = false
}

variable "ebs_csi_driver_version" {
  description = "Version of the AWS EBS CSI Driver add-on"
  type        = string
  default     = null # Uses latest version
}

variable "enable_pod_identity_agent" {
  description = "Whether to enable the EKS Pod Identity Agent addon"
  type        = bool
  default     = false
}

variable "cluster_admin_arns" {
  description = "List of IAM user/role ARNs to grant cluster admin access via EKS access entries"
  type        = list(string)
  default     = []
}

variable "cluster_authentication_mode" {
  description = "Authentication mode for the EKS cluster. Valid values: CONFIG_MAP, API, API_AND_CONFIG_MAP. Defaults to API_AND_CONFIG_MAP when capabilities are enabled, otherwise CONFIG_MAP."
  type        = string
  default     = "API_AND_CONFIG_MAP"

  validation {
    condition     = contains(["CONFIG_MAP", "API", "API_AND_CONFIG_MAP"], var.cluster_authentication_mode)
    error_message = "cluster_authentication_mode must be one of: CONFIG_MAP, API, API_AND_CONFIG_MAP"
  }
}

variable "tags" {
  type    = map(string)
  default = {}
}
