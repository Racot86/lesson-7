# Comment out the backend configuration initially to create the S3 bucket first
# Uncomment after running 'terraform apply' to create the bucket

terraform {
  backend "s3" {
    bucket         = "terraform-state-lesson5"
    key            = "lesson-5/terraform.tfstate"
    region         = "us-west-2"
    use_lockfile   = true
    encrypt        = true
  }
}

