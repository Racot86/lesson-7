Lesson 7 — EKS + ECR + Helm deployment for Node.js app

This repository provisions an EKS cluster and an ECR repository with Terraform, builds and pushes a Node.js app image to ECR, and deploys the app to the cluster using a Helm chart. The deployment includes a ConfigMap for environment variables and an HPA.

If you prefer to run the app locally (Docker or Docker Compose), see the Local development section below.

Compatibility and versions
- Terraform: >= 1.6
- AWS provider: ~> 5.65 (pinned for compatibility with EKS module 20.x)
- EKS module: terraform-aws-modules/eks/aws ~> 20.24.0
- Kubernetes provider: >= 2.27
- Helm provider: >= 2.13
- Kubernetes: 1.30 target

Prerequisites
- AWS account and credentials with permissions for EKS, ECR, EC2, IAM, S3 (optional), and DynamoDB (optional)
  - AWS CLI v2 configured (env vars or aws configure / AWS SSO)
- Terraform >= 1.6
- kubectl
- Helm v3
- Docker (for building/pushing the image)
- Existing VPC and subnets (private subnets for nodes; public or private LBs depending on your setup)

Optional (for remote Terraform state):
- S3 bucket and DynamoDB table (or let the provided module create them for you)

Project layout
- Terraform root: backend.tf, main.tf, outputs.tf
- Modules: modules/ecr, modules/eks, modules/s3-backend
- App sources and local compose: backend-source/
- Helm chart: charts/node-app/
- Reference only: devOps-lesson-7/ (example stack kept for comparison; the active stack is the project root)

0) Configure AWS credentials
Choose one method:
- Environment variables: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_DEFAULT_REGION
- AWS profile: aws configure --profile <profile> and export AWS_PROFILE=<profile>
- AWS SSO: aws sso login --profile <sso-profile> and export AWS_PROFILE=<sso-profile>

1) (Optional) Remote state backend
You can store Terraform state remotely in S3 with DynamoDB locking.

Option A — create backend infra with the included module (separate run):
1. Decide bucket/table names, e.g. tf-state-<your-unique-suffix> and tf-lock-table.
2. In a separate state/workspace (or before enabling backend), apply the module by creating a small TF stack using modules/s3-backend (variables: bucket_name, dynamodb_table_name, region).
3. Fill and uncomment the backend block in backend.tf:
   backend "s3" {
     bucket         = <your-tf-state-bucket>
     key            = <path/lesson-7/terraform.tfstate>
     region         = <your-region>
     dynamodb_table = <your-lock-table>
     encrypt        = true
   }
4. Run: terraform init -migrate-state

Option B — keep local state (default). Do nothing; state will be stored in ./terraform.tfstate.

2) Provide required variables
Create terraform.tfvars at repo root with your values (example):
  region              = "us-east-1"
  vpc_id              = "vpc-xxxx"
  private_subnet_ids  = ["subnet-aaa", "subnet-bbb"]
  public_subnet_ids   = ["subnet-ccc", "subnet-ddd"]  # optional (for public LoadBalancer)
  cluster_name        = "lesson-7-eks"
  ecr_repo_name       = "lesson-7-node-app"
  node_instance_types = ["t3.small"]
  min_capacity        = 2
  desired_capacity    = 2
  max_capacity        = 6

Note: Use the VPC and subnet IDs from your previous assignment or your existing network.
Do not commit terraform.tfvars to version control. Consider adding a terraform.tfvars.example without secrets for sharing defaults.

3) Create EKS and ECR with Terraform
  terraform init
  terraform apply

Outputs will include:
- ecr_repository_url — ECR repo to push the image
- eks_cluster_name, eks_cluster_endpoint, eks_cluster_oidc_issuer_url

Long-running apply (what is normal and how to watch)
- Creating an EKS cluster typically takes 20–40 minutes; up to ~60 minutes can still be normal.
- In another terminal you can watch status without interrupting Terraform:
  aws eks describe-cluster --name <cluster_name> --region <region> --query 'cluster.status'
  aws eks describe-nodegroup --cluster-name <cluster_name> --nodegroup-name default --region <region> --query 'nodegroup.status'
  aws eks describe-nodegroup --cluster-name <cluster_name> --nodegroup-name default --region <region> --query 'nodegroup.health.issues'

4) Build and push the Docker image to ECR
Replace placeholders with your values.
  aws ecr get-login-password --region <region> | docker login --username AWS --password-stdin <account_id>.dkr.ecr.<region>.amazonaws.com
  cd backend-source/app
  docker build -t lesson-7-node-app:latest .
  docker tag lesson-7-node-app:latest <account_id>.dkr.ecr.<region>.amazonaws.com/lesson-7-node-app:latest
  docker push <account_id>.dkr.ecr.<region>.amazonaws.com/lesson-7-node-app:latest

Tip: The ECR repository URL is also available from `terraform output ecr_repository_url`.

5) Configure kubectl for the new cluster
  aws eks update-kubeconfig --region <region> --name <cluster_name>
  kubectl get nodes

6) Deploy the app with Helm
1. Edit charts/node-app/values.yaml:
   - Set image.repository to your ECR repository URL (without the tag), e.g. <account_id>.dkr.ecr.<region>.amazonaws.com/lesson-7-node-app
   - Optionally set image.tag (default latest).
   - Fill config with your database settings:
     POSTGRES_HOST, POSTGRES_DB, POSTGRES_USER, POSTGRES_PASSWORD, POSTGRES_PORT (default 5432), and PORT (default 8000).
2. Install or upgrade the release:
  helm upgrade --install node-app charts/node-app --namespace default
3. Check resources:
  kubectl get deploy,svc,hpa,pods
4. When the Service of type LoadBalancer is ready, access the app using its external hostname on port 80.
   To print it quickly:
     kubectl get svc node-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

7) Verify the application
- Health endpoint:
  curl http://<external-lb-hostname>/
- Database test (requires valid DB envs and network reachability):
  curl http://<external-lb-hostname>/db-test

Local development (optional)
Option A — Node directly:
  cd backend-source/app
  npm install
  PORT=8000 npm start

Option B — Docker:
  cd backend-source/app
  docker build -t lesson-7-node-app:local .
  docker run --rm -p 8000:8000 \
    -e POSTGRES_HOST=<host> -e POSTGRES_DB=<db> -e POSTGRES_USER=<user> \
    -e POSTGRES_PASSWORD=<password> -e POSTGRES_PORT=5432 -e PORT=8000 \
    lesson-7-node-app:local

Option C — Docker Compose (includes Nginx example):
  cd backend-source
  # Ensure .env has your DB variables if needed
  docker compose up --build
Then browse http://localhost:8000 (or via Nginx if configured).

Troubleshooting
- HPA remains pending: Ensure metrics-server is installed in the cluster (EKS add-on or Helm chart).
- ImagePullBackOff: Confirm image.repository and image.tag are correct and the nodes can pull from your ECR (same account/region or proper permissions).
- Unauthorized when pushing to ECR: Re-run the aws ecr get-login-password login step and verify your AWS profile/region.
- Pods crash on startup: Verify env vars in the ConfigMap and that the database is reachable from the cluster subnets (security groups, routing, and DNS).
- kubectl cannot connect: Re-run aws eks update-kubeconfig with the correct --region and --name.

Common EKS delays and quick mitigations
- Capacity in selected AZ for instance type (default t3.small): allow alternatives or change type in terraform.tfvars, e.g.
  node_instance_types = ["t3a.small", "t3.small"]
- Service quotas (vCPU/instance counts): check EC2 quotas and request increase if needed.
- Networking: ensure private subnets have NAT egress for node bootstrap; security groups/NACLs aren’t blocking.

Cleanup
- Remove the Helm release:
  helm uninstall node-app --namespace default
- Destroy infrastructure (this also deletes the ECR repo; empty images first if needed):
  terraform destroy
- To delete ECR images manually (if the repo is not empty): Use AWS Console or CLI to batch delete images.

What to keep in repo vs. ignore
- Keep: IaC (Terraform files), modules/, charts/, backend-source/ app source, README.md, task.MD
- Do not commit: terraform.tfvars, any *.tfvars with secrets, backend-source/app/.env
- Ignore generated files and caches by using .gitignore like below.

Suggested .gitignore
```
# Terraform
.terraform/
.terraform.lock.hcl
terraform.tfstate
terraform.tfstate.backup
crash.log

# Local config
terraform.tfvars
*.auto.tfvars
*.tfvars

# Node
backend-source/app/node_modules/
backend-source/app/.env
npm-debug.log*
yarn-error.log

# OS/IDE
.DS_Store
.idea/
.vscode/
```

Notes
- The Helm templates use Go templating ({{ ... }}), which may be flagged by plain YAML linters but is valid in Helm.
- The EKS module targets Kubernetes 1.30 and creates a single managed node group by default (t3.small). Adjust in terraform.tfvars as needed.
- Avoid committing secrets. Use environment variables, secret managers, or Kubernetes Secrets for sensitive data.
 - Providers are pinned for compatibility: AWS provider ~> 5.65 with EKS module ~> 20.24.0.
