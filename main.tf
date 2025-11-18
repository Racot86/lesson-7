provider "aws" {
  region = "us-west-2"
}

# S3 Backend Module
module "s3_backend" {
  source      = "./modules/s3-backend"
  bucket_name = "terraform-state-lesson5"
  table_name  = "terraform-locks"
}

# VPC Module
module "vpc" {
  source             = "./modules/vpc"
  vpc_cidr_block     = "10.0.0.0/16"
  public_subnets     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnets    = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
  availability_zones = ["us-west-2a", "us-west-2b", "us-west-2c"]
  vpc_name           = "lesson-5-vpc"
}

# ECR Module
module "ecr" {
  source      = "./modules/ecr"
  ecr_name    = "lesson-5-ecr"
  scan_on_push = true
  tags = {
    Environment = "Development"
    Project     = "Lesson-5"
  }
}

# EKS Module
module "eks" {
  source         = "./modules/eks"
  cluster_name   = "lesson-8-9-eks"
  subnet_ids     = module.vpc.private_subnet_ids
  instance_type  = "t3.medium"
  desired_size   = 2
  min_size       = 1
  max_size       = 3
}

# Fetch EKS connection data only after the cluster is created
data "aws_eks_cluster" "eks" {
  name       = module.eks.eks_cluster_name
  depends_on = [module.eks]
}

data "aws_eks_cluster_auth" "eks" {
  name       = module.eks.eks_cluster_name
  depends_on = [module.eks]
}

# Jenkins Module (Helm on EKS)
module "jenkins" {
  source               = "./modules/jenkins"
  namespace            = "cicd"
  eks_cluster_name     = module.eks.eks_cluster_name
  eks_cluster_endpoint = module.eks.eks_cluster_endpoint

  # Inject EKS auth materials to avoid early data lookups inside the module
  eks_cluster_ca    = data.aws_eks_cluster.eks.certificate_authority[0].data
  eks_cluster_token = data.aws_eks_cluster_auth.eks.token
}

# Argo CD Module (Helm on EKS)
module "argo_cd" {
  source               = "./modules/argo_cd"
  namespace            = "argocd"
  eks_cluster_name     = module.eks.eks_cluster_name
  eks_cluster_endpoint = module.eks.eks_cluster_endpoint

  # Inject EKS auth materials to avoid early data lookups inside the module
  eks_cluster_ca    = data.aws_eks_cluster.eks.certificate_authority[0].data
  eks_cluster_token = data.aws_eks_cluster_auth.eks.token

  # Point Argo CD to this repo's Helm chart for the app
  app_repo_url = "https://github.com/misfits3z/lesson-7.git"
  app_revision = "main"
  app_path     = "charts/node-app"
}
