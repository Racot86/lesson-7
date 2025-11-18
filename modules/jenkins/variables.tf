variable "namespace" {
  description = "Namespace to install Jenkins into"
  type        = string
  default     = "cicd"
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
