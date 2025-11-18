# Lesson-7: AWS Infra + GitOps CI/CD (Jenkins + Helm + Terraform + Argo CD)

## Overview

This project implements a complete path from infrastructure to GitOps-style application delivery:

1) Infrastructure (Terraform)
   - S3 + DynamoDB for Terraform state backend
   - VPC with public/private subnets across 3 AZs
   - ECR repository for application images
   - EKS cluster (control plane + managed node group)

2) Platform services (Helm via Terraform)
   - Jenkins installed to the cluster (Helm chart) for CI
   - Argo CD installed to the cluster (Helm chart) for CD

3) Application delivery
   - Application packaged as a Helm chart: `charts/node-app`
   - CI builds app image and pushes to ECR, then updates the Helm `values.yaml` tag
   - Argo CD watches Git and automatically syncs the application to the cluster

---

## Project Structure

```
.
├── Jenkinsfile                    # CI pipeline (Kaniko → ECR → update Helm → push)
├── main.tf                        # Main configuration: wires modules together
├── backend.tf                     # S3 backend configuration (commented initially)
├── outputs.tf                     # Root module outputs
│
├── backend-source/                # Application source built by Jenkins
│   ├── app/
│   │   ├── Dockerfile
│   │   ├── index.js
│   │   ├── db.js
│   │   └── package.json
│   ├── db/
│   │   └── init.sql
│   └── nginx/
│       ├── Dockerfile
│       └── nginx.conf
│
├── charts/
│   └── node-app/                  # Helm chart for the Node.js application
│       ├── Chart.yaml
│       ├── values.yaml            # Holds image repository/tag and app config
│       └── templates/
│           ├── deployment.yaml
│           ├── service.yaml
│           └── configmap.yaml
│           # (HPA template can be added if needed)
│
└── modules/                       # Reusable modules
    ├── s3-backend/                # State management (S3 + DynamoDB)
    │   ├── s3.tf
    │   ├── dynamodb.tf
    │   ├── variables.tf
    │   └── outputs.tf
    │
    ├── vpc/                       # Networking (VPC, subnets, routes)
    │   ├── vpc.tf
    │   ├── routes.tf
    │   ├── variables.tf
    │   └── outputs.tf
    │
    ├── ecr/                       # Container registry (ECR)
    │   ├── ecr.tf
    │   ├── variables.tf
    │   └── outputs.tf
    │
    ├── eks/                       # Kubernetes control plane and node group
    │   ├── eks.tf
    │   ├── node.tf
    │   ├── variables.tf
    │   └── outputs.tf
    │
    ├── jenkins/                   # Helm release for Jenkins (CI)
    │   ├── providers.tf
    │   ├── jenkins.tf
    │   ├── variables.tf
    │   └── values.yaml
    │
    └── argo_cd/                   # Helm release for Argo CD (CD) + app chart
        ├── providers.tf
        ├── argocd.tf
        ├── variables.tf
        ├── values.yaml
        └── charts/
            ├── Chart.yaml
            ├── values.yaml
            └── templates/
                ├── application.yaml
                └── repository.yaml
```

---

## Module Descriptions

### 1. S3 Backend Module

Creates infrastructure for secure Terraform state management:

* S3 bucket with versioning and encryption
* DynamoDB table for state locking
* Public access blocking for enhanced security

### 2. VPC Module

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
