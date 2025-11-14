terraform {
  # Configure remote state backend in S3 (uncomment and fill values to enable)
  # backend "s3" {
  #   bucket         = var.tf_state_bucket
  #   key            = var.tf_state_key
  #   region         = var.region
  #   dynamodb_table = var.tf_state_lock_table
  #   encrypt        = true
  # }
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.65"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.27"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.13"
    }
  }
}
