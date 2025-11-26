
Establishes a complete network infrastructure:

* VPC with configurable CIDR block
* Public subnets with Internet Gateway access
* Private subnets with NAT Gateway access
* Multi-AZ deployment for high availability
* Proper route tables and associations

### 3. ECR Module

Provides Docker image management:

* ECR repository for storing container images
* Repository access policies
* Image lifecycle management
* Optional image scanning on push

### 4. EKS Module

Creates an Amazon EKS cluster and a managed node group:

* EKS control plane IAM role and cluster
* Managed node group IAM role and policies
* Node group across provided private subnets

### 5. Jenkins Module

Installs Jenkins via Helm into the cluster (default namespace `cicd`):

* Exposes Jenkins via `LoadBalancer` Service
* Pre-installs core plugins and JCasC template for a Kaniko agent

### 6. Argo CD Module

Installs Argo CD via Helm (default namespace `argocd`) and deploys an internal chart that defines an `Application` pointing to this repository’s Helm chart (`charts/node-app`). Any change to the chart or its `values.yaml` in Git is reconciled automatically in the cluster.

---

## Usage Instructions

### Prerequisites

* AWS CLI installed and configured with appropriate credentials
* Terraform installed (version 1.0.0 or newer)

### Initial Setup

Follow these steps to properly initialize the infrastructure:

1. **Prepare backend configuration**
   * The `backend.tf` file is initially commented out (S3 bucket must exist first)

2. **Initialize with local backend**
   ```bash
   terraform init
   ```

3. **Create infrastructure resources**
   ```bash
   terraform apply
   ```

4. **Enable S3 backend**
   * Uncomment the backend configuration in `backend.tf`

5. **Migrate state to S3**
   ```bash
   terraform init -migrate-state
   ```
   * When prompted, type 'yes' to confirm migration

> Note: The backend uses `use_lockfile` for state locking.

### Common Operations

**Plan changes:**
```bash
terraform plan
```

**Apply changes:**
```bash
terraform apply
```

**Destroy infrastructure:**
```bash
terraform destroy
```

### ECR Authentication

To push or pull Docker images from the ECR repository:

1. **Get authentication token:**
   ```bash
   aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin ACCOUNT_ID.dkr.ecr.us-west-2.amazonaws.com
   ```
   Replace `ACCOUNT_ID` with your AWS account ID (available in the ECR repository URL output)

2. **Push an image:**
   ```bash
   docker push ACCOUNT_ID.dkr.ecr.us-west-2.amazonaws.com/lesson-5-ecr:tag
   ```

3. **Pull an image:**
   ```bash
   docker pull ACCOUNT_ID.dkr.ecr.us-west-2.amazonaws.com/lesson-5-ecr:tag

---

## CI/CD Flow (Jenkins → ECR → Git → Argo CD)

1) Jenkins (root Jenkinsfile) builds and pushes a Docker image to ECR using a Kubernetes agent with Kaniko.
   - Build context: `backend-source/app` (Dockerfile lives here)
   - Target ECR repository: `lesson-5-ecr` (from Terraform `modules/ecr`)
2) Jenkins updates the Helm chart values at `charts/node-app/values.yaml` and commits back to `main`:
   - On the first run, it replaces `image.repository: REPLACE_ME_ECR_REPOSITORY` with your actual ECR registry/repository (e.g., `<ACCOUNT_ID>.dkr.ecr.us-west-2.amazonaws.com/lesson-5-ecr`).
   - On every run, it updates `image.tag` to the Jenkins build number.
3) Argo CD, configured to watch this repository path, detects the change and syncs the app to EKS automatically.

### Jenkins: prerequisites and configuration

- Jenkins is installed into the cluster by Terraform/Helm and exposed via a LoadBalancer Service.
- Default admin credentials are defined in `modules/jenkins/values.yaml` (username `admin`, password `admin123`). Change these for any non-demo use.
- Create two Jenkins credentials (referenced by the Jenkinsfile):
  - `aws-creds` (Kind: Username with password) → username=`AWS_ACCESS_KEY_ID`, password=`AWS_SECRET_ACCESS_KEY` with permissions to ECR in `us-west-2`.
  - `git-creds` (Kind: Username with password or token) → has push rights to this repository’s `main` branch.

### Jenkins pipeline in this repo

The root `Jenkinsfile` already implements the required flow end-to-end:
- Resolves AWS account/registry dynamically with AWS CLI
- Builds and pushes the image with Kaniko from `backend-source/app`
- Updates `charts/node-app/values.yaml` (repository first run only; tag every run)
- Commits and pushes back to `main`

You can create a Jenkins Pipeline job that uses the Jenkinsfile from SCM (this repository) and run it immediately after configuring credentials.

---

## Important Notes

* The S3 bucket has `prevent_destroy = false`, allowing it to be destroyed with `terraform destroy`
  * Note: This was changed from the default `true` setting to enable complete infrastructure teardown
  * In production environments, consider setting this back to `true` to protect state storage
* NAT Gateways incur significant costs - consider disabling for development environments
* ECR authentication tokens are valid for 12 hours
* Proper IAM permissions are required to interact with the created resources

### 7. RDS Module (Aurora or Standalone)

Production-ready, reusable Terraform module that can provision either:
- a single RDS instance (PostgreSQL/MySQL), or
- an Aurora cluster (PostgreSQL/MySQL-compatible),
based on the boolean flag `use_aurora`.

What it creates in both modes:
- DB Subnet Group (uses provided private subnet IDs)
- Security Group with allowed CIDR rules on the DB port
- Parameter Group(s) with basic parameters (max_connections, log_statement, work_mem)

Key variables:
- name: base name used for identifiers and tags
- use_aurora: true to create Aurora cluster, false for single instance (default false)
- engine: e.g. "postgres", "aurora-postgresql", "mysql", "aurora-mysql"
- engine_version: version string, e.g. "14.7"
- instance_class: e.g. "db.t3.medium"
- parameter_group_family: e.g. "postgres14" or "aurora-postgresql14"
- vpc_id, subnet_ids: to place DB in private subnets and attach SG
- db_name, username, password, port
- allowed_cidr_blocks: list of CIDRs allowed to access DB on port
- aurora_instance_count: number of cluster instances (writer + readers), default 1

Outputs:
- db_subnet_group_name, security_group_id, endpoint, reader_endpoint (Aurora only), port

Example usage for a Node.js app with PostgreSQL (standalone RDS):

```
module "rds" {
  source = "./modules/rds"

  name                    = "lesson7-db"
  use_aurora              = false
  engine                  = "postgres"
  engine_version          = "14.7"
  instance_class          = "db.t3.micro"
  parameter_group_family  = "postgres14"

  vpc_id      = module.vpc.vpc_id
  subnet_ids  = module.vpc.private_subnet_ids
  port        = 5432

  db_name   = var.db_name
  username  = var.db_username
  password  = var.db_password

  allowed_cidr_blocks = ["10.0.0.0/16"]

  tags = {
    Environment = "dev"
    Project     = "lesson-7"
  }
}
```

Aurora PostgreSQL variant:

```
module "rds" {
  source = "./modules/rds"

  name                    = "lesson7-aurora"
  use_aurora              = true
  engine                  = "aurora-postgresql"
  engine_version          = "14.6"
  instance_class          = "db.r6g.large"
  parameter_group_family  = "aurora-postgresql14"
  aurora_instance_count   = 2  # 1 writer + 1 reader

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids
  port       = 5432

  db_name   = var.db_name
  username  = var.db_username
  password  = var.db_password
}
```

Tip for the Node app: wire the DB connection string via Helm values and a Kubernetes Secret, using the `module.rds.endpoint` output together with `module.rds.port`.
