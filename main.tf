variable "region" {
  description = "AWS region to use"
  type        = string
  default     = "us-east-1"
}

variable "vpc_id" {
  description = "ID of the existing VPC to deploy EKS into"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for worker nodes"
  type        = list(string)
  validation {
    condition     = length(var.private_subnet_ids) >= 2
    error_message = "Provide at least two private subnet IDs in different Availability Zones for a stable EKS deployment."
  }
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs (for load balancers, optional)"
  type        = list(string)
  default     = []
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "lesson-7-eks"
}

variable "ecr_repo_name" {
  description = "Name of the ECR repository for the Node.js image"
  type        = string
  default     = "lesson-7-node-app"
}

variable "node_instance_types" {
  description = "Instance types for the EKS node group"
  type        = list(string)
  default     = ["t3.small"]
}

variable "desired_capacity" {
  description = "Desired size for the node group"
  type        = number
  default     = 2
}

variable "min_capacity" {
  description = "Min size for the node group"
  type        = number
  default     = 2
}

variable "max_capacity" {
  description = "Max size for the node group"
  type        = number
  default     = 6
}

variable "tf_state_bucket" {
  description = "S3 bucket name for Terraform state (optional)"
  type        = string
  default     = null
}

variable "tf_state_key" {
  description = "Key path for Terraform state (optional)"
  type        = string
  default     = null
}

variable "tf_state_lock_table" {
  description = "DynamoDB table name for state locking (optional)"
  type        = string
  default     = null
}

provider "aws" {
  region = var.region
}

# ECR repository to store the application image
module "ecr" {
  source    = "./modules/ecr"
  repo_name = var.ecr_repo_name
}

# EKS cluster in an existing VPC
module "eks" {
  source               = "./modules/eks"
  region               = var.region
  cluster_name         = var.cluster_name
  vpc_id               = var.vpc_id
  private_subnet_ids   = var.private_subnet_ids
  public_subnet_ids    = var.public_subnet_ids
  node_instance_types  = var.node_instance_types
  min_capacity         = var.min_capacity
  desired_capacity     = var.desired_capacity
  max_capacity         = var.max_capacity
}
