variable "region" {
  description = "AWS region"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID to deploy EKS into"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for EKS"
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "Public subnet IDs (optional, for LB)"
  type        = list(string)
  default     = []
}

variable "node_instance_types" {
  description = "Node group instance types"
  type        = list(string)
  default     = ["t3.small"]
}

variable "min_capacity" {
  type        = number
  default     = 2
}

variable "desired_capacity" {
  type        = number
  default     = 2
}

variable "max_capacity" {
  type        = number
  default     = 6
}
