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

variable "shared_alb_ingress_group_name" {
  type        = string
  default     = "shared-alb"
  description = "Name of the ingress group for shared ALB. All ingresses with this group name will share the same ALB."
}

variable "domain_name" {
  type        = string
  description = "Domain name for ArgoCD (e.g., example.com). Used to construct the full URL."
}

variable "shared_alb_security_group_id" {
  type        = string
  default     = ""
  description = "Security group ID for shared ALB with IP restrictions. Empty if IP restrictions are not configured."
}

variable "alb_arn" {
  type        = string
  description = "ARN of the Application Load Balancer"
  default     = ""
}


variable "route53_name" {
  type        = string
  default     = "argocd"
  description = "Name for the Route53 record (e.g., 'argocd' creates argocd.example.com)"
}

variable "create_route53" {
  type        = bool
  default     = true
  description = "Create Route53 alias record for the ALB. Use a static value so count is known at plan time. If alb_arn is empty at apply time, a precondition will fail with instructions to run -target=module.shared_alb first."
}
