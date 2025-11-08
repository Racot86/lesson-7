# S3 Backend Outputs
output "s3_bucket_id" {
  description = "The ID of the S3 bucket for Terraform state storage"
  value       = module.s3_backend.s3_bucket_id
}

output "dynamodb_table_name" {
  description = "The name of the DynamoDB table for state locking"
  value       = module.s3_backend.dynamodb_table_name
}

# VPC Outputs
output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "List of IDs of public subnets"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "List of IDs of private subnets"
  value       = module.vpc.private_subnet_ids
}

# ECR Outputs
output "ecr_repository_url" {
  description = "The URL of the ECR repository"
  value       = module.ecr.repository_url
}

output "ecr_repository_name" {
  description = "The name of the ECR repository"
  value       = module.ecr.repository_name
}
