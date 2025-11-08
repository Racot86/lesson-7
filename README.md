# Terraform Infrastructure for AWS

## Overview

This project provides Terraform configurations to set up a complete AWS infrastructure with:

* **State Management**: S3 bucket with DynamoDB for secure state storage and locking
* **Networking**: VPC with public/private subnets across multiple availability zones
* **Container Registry**: ECR repository for Docker image storage and management

---

## Project Structure

```
.
├── main.tf                  # Main configuration file
├── backend.tf               # S3 backend configuration
├── outputs.tf               # Root module outputs
│
└── modules/                 # Reusable modules
    ├── s3-backend/          # State management module
    │   ├── s3.tf            # S3 bucket configuration
    │   ├── dynamodb.tf      # DynamoDB table configuration
    │   ├── variables.tf     # Input variables
    │   └── outputs.tf       # Output values
    │
    ├── vpc/                 # Network module
    │   ├── vpc.tf           # VPC and gateway configuration
    │   ├── routes.tf        # Routing configuration
    │   ├── variables.tf     # Input variables
    │   └── outputs.tf       # Output values
    │
    └── ecr/                 # Container registry module
        ├── ecr.tf           # ECR repository configuration
        ├── variables.tf     # Input variables
        └── outputs.tf       # Output values
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

> **Note:** The backend uses `use_lockfile` instead of the deprecated `dynamodb_table` parameter.

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
   ```

---

## Important Notes

* The S3 bucket has `prevent_destroy = false`, allowing it to be destroyed with `terraform destroy`
  * Note: This was changed from the default `true` setting to enable complete infrastructure teardown
  * In production environments, consider setting this back to `true` to protect state storage
* NAT Gateways incur significant costs - consider disabling for development environments
* ECR authentication tokens are valid for 12 hours
* Proper IAM permissions are required to interact with the created resources
