variable "namespace" {
  type        = string
  default     = "default"
  description = "Kubernetes namespace for the landing page"
}

variable "subnet_ids" {
  type        = list(string)
  description = "List of subnet IDs for ALB (should be public subnets for internet-facing ALB)"
}

variable "shared_alb_ingress_group_name" {
  type        = string
  description = "Name of the ingress group for shared ALB"
}

variable "enable_https" {
  type        = bool
  default     = false
  description = "Enable HTTPS for landing page ingress using ACM certificate"
}

variable "certificate_arn" {
  type        = string
  default     = ""
  description = "ACM certificate ARN for HTTPS. Required when enable_https is true."
}

variable "ssl_redirect" {
  type        = bool
  default     = true
  description = "Redirect HTTP to HTTPS when enable_https is true"
}

variable "shared_alb_security_group_id" {
  type        = string
  default     = ""
  description = "Security group ID for shared ALB with IP restrictions. If provided, will be attached to the ALB."
}

variable "services" {
  type = list(object({
    name        = string
    url         = string
    description = string
  }))
  description = "List of services to display on the landing page. Each service should have a name, URL, and description."
  default     = []
}

variable "favicon_path" {
  type        = string
  default     = null
  description = "Path to favicon.svg file. If null, a default favicon will be used. Path should be relative to the module directory."
}

variable "domain_name" {
  type        = string
  description = "Domain name for Route53 record"
}

variable "alb_arn" {
  type        = string
  description = "ARN of the Application Load Balancer"
  default     = ""
}

variable "route53_name" {
  type        = string
  default     = "platform"
  description = "Name for the Route53 record (e.g., 'platform' creates platform.example.com)"
}
