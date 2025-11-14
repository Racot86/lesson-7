variable "bucket_name" {
  description = "S3 bucket name for Terraform remote state"
  type        = string
}

variable "dynamodb_table_name" {
  description = "DynamoDB table name for state locking"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}
