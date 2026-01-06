variable "namespace" {
  type    = string
  default = "argocd"
}

variable "chart_version" {
  type        = string
  default     = "0.1.4"
  description = "Version of the k8sforge/argocd-chart Helm chart"
}

variable "repo_url" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "target_revision" {
  type    = string
  default = "main"
}

variable "subnet_ids" {
  type        = list(string)
  description = "List of subnet IDs for ALB (should be public subnets for internet-facing ALB)"
}

variable "atlantis_chart_version" {
  type        = string
  default     = "0.1.0"
  description = "Version of the k8sforge/atlantis-charts Helm chart"
}
