variable "name" {
  type        = string
  description = "Name prefix for resources (e.g., cluster name)"
}

variable "cluster_name" {
  type        = string
  description = "EKS cluster name (used for ALB discovery tags)"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID where the ALB is deployed"
}

variable "ingress_group_name" {
  type        = string
  default     = ""
  description = "Name of the ingress group for shared ALB. All ingresses with this group name will share the same ALB."
}

variable "allowed_ips" {
  type        = list(string)
  default     = ["0.0.0.0/0"]
  description = "List of CIDR blocks allowed to access the shared ALB. If empty, all IPs are allowed."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags to apply to resources"
}

variable "subnet_ids" {
  type        = list(string)
  description = "Public subnet IDs for ALB"
}
