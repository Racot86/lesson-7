variable "namespace" {
  description = "Namespace to install Argo CD into"
  type        = string
  default     = "argocd"
}

variable "chart_version" {
  description = "Argo CD chart version"
  type        = string
  default     = "5.51.6"
}

variable "eks_cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "eks_cluster_endpoint" {
  description = "EKS cluster endpoint"
  type        = string
}

variable "eks_cluster_ca" {
  description = "EKS cluster CA certificate (base64)"
  type        = string
}

variable "eks_cluster_token" {
  description = "EKS cluster auth token"
  type        = string
}

variable "app_repo_url" {
  description = "Git repository URL with Helm chart/apps"
  type        = string
}

variable "app_revision" {
  description = "Branch/Tag for Argo CD apps"
  type        = string
  default     = "main"
}

variable "app_path" {
  description = "Path to Helm chart in the repo"
  type        = string
}
