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

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
