# Terraform variables for Lesson 7 — fill with your real values

# AWS region to deploy into
region = "us-east-1"

# Existing VPC (from your previous homework / environment)
vpc_id = "vpc-05171a531ca8c17e8"

# Private subnets for EKS worker nodes (use at least two, in different AZs)
private_subnet_ids = [
  "subnet-04706571f13813f0e",
  "subnet-095c3a5e6bd248e07"
]

# Optional: Public subnets if you plan to use public LoadBalancer services
# public_subnet_ids = [
#   "<public-subnet-id-1>",
#   "<public-subnet-id-2>"
# ]

# Optional overrides (defaults exist in main.tf). Uncomment to change.
# cluster_name        = "lesson-7-eks"
# ecr_repo_name       = "lesson-7-node-app"
# node_instance_types = ["t3.small"]
# min_capacity        = 2
# desired_capacity    = 2
# max_capacity        = 6

# After filling the values, run:
#   terraform init
#   terraform apply
