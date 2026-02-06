# Lab 3: Deploy Pipeline & Promote Changes

*Terraform Day 3: Enterprise Deployment & Operations*

| | |
|---|---|
| **Course** | Terraform on AWS (300-Level) |
| **Module** | CI/CD for Terraform |
| **Duration** | 75 minutes |
| **Difficulty** | Advanced |
| **Prerequisites** | Labs 1-2 completed |

---

## Lab Overview

### Narrative

NovaTech's CTO made it clear after the production incident: *"No human runs terraform apply against production."* A misconfigured security group change, applied directly from an engineer's laptop at 4:47 PM on a Friday, took down the payment gateway for 23 minutes. The post-mortem was brutal. No peer review. No plan artifact. No audit trail. No approval gate. Jordan, the lead infrastructure engineer, was tasked with fixing this -- permanently.

Jordan's team needs to build an automated pipeline. Not a script. Not a cron job. A real, auditable, multi-environment deployment pipeline with mandatory approval gates before every environment receives changes. The CTO's mandate is simple: the only way Terraform changes reach staging or production is through the pipeline. Period.

Your task is to deploy a complete CI/CD pipeline using AWS CodePipeline that validates, plans, and applies Terraform changes with mandatory approval gates before each environment. You will build the pipeline infrastructure itself using Terraform (yes, Terraform deploying a pipeline that deploys Terraform), push application code through it, and experience the full promotion workflow from commit to production. When you are done, pushing a commit to the repository will automatically trigger the full pipeline -- and the only way changes reach production is through the automated, auditable workflow.

### Learning Objectives

By the end of this lab, you will:

- Deploy CI/CD pipeline infrastructure using Terraform in staged layers
- Understand every component of a Terraform deployment pipeline (CodeCommit, CodeBuild, CodePipeline)
- Configure inline buildspec definitions for validate, plan, and apply stages
- Push Terraform changes through an automated pipeline with approval gates
- Experience environment promotion from staging to production
- Make a change and watch it flow through the complete pipeline lifecycle

---

## Architecture Overview

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│ CodeCommit  │───>│  Validate   │───>│    Plan     │───>│   Approve   │───>│    Apply    │
│   (Source)  │    │ (CodeBuild) │    │ (CodeBuild) │    │  (Manual)   │    │ (CodeBuild) │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
                                                                                    │
                                                                             ┌──────▼──────┐
                                                                             │   Staging   │
                                                                             │ (us-east-1) │
                                                                             └──────┬──────┘
                                                                                    │
                              ┌─────────────┐    ┌─────────────┐                    │
                              │   Approve   │───>│    Apply    │<───────────────────┘
                              │  (Manual)   │    │ (CodeBuild) │
                              └─────────────┘    └─────────────┘
                                                        │
                                                 ┌──────▼──────┐
                                                 │ Production  │
                                                 │ (us-west-2) │
                                                 └─────────────┘
```

**Pipeline Flow:**
1. Developer pushes to CodeCommit `main` branch
2. **Validate** -- `terraform fmt -check` and `terraform validate` catch syntax errors
3. **Plan Staging** -- generates execution plan for staging environment
4. **Approve Staging** -- manual gate; reviewer inspects the plan
5. **Apply Staging** -- applies the approved plan to staging (us-east-1)
6. **Plan Production** -- generates execution plan for production environment
7. **Approve Production** -- manual gate; senior engineer or manager approves
8. **Apply Production** -- applies the approved plan to production (us-west-2)

### Key Concepts

| Term | Definition |
|------|------------|
| **CodeCommit** | AWS-managed Git repository service that acts as the pipeline source |
| **CodeBuild** | Fully managed build service that runs commands in a containerized environment |
| **CodePipeline** | Continuous delivery service that orchestrates stages, actions, and transitions |
| **Buildspec** | YAML specification defining the commands CodeBuild executes in each phase |
| **Approval Gate** | Manual action requiring human review before the pipeline proceeds to the next stage |
| **Artifact** | Output from one pipeline stage (e.g., a `tfplan` file) passed as input to the next |
| **Environment Promotion** | The practice of deploying changes to staging first, then promoting to production after validation |
| **Staged Deployment** | Building infrastructure in layers using `-target` to control the order of resource creation |

---

## Part A: Review Pipeline Terraform (10 min)

In this section, you will create all the Terraform configuration files that define the pipeline infrastructure. You will not deploy anything yet -- the goal is to understand each component before applying.

### Step 1: Create Working Directory

```bash
mkdir -p ~/terraform-day3/lab3-pipeline
cd ~/terraform-day3/lab3-pipeline
```

### Step 2: Create Provider and Backend Configuration

Create `providers.tf`:

```hcl
# providers.tf - Provider configuration and S3 backend
# NOTE: Use the bucket and table names from your Lab 1 terraform output

terraform {
  required_version = ">= 1.5.0"

  backend "s3" {
    bucket         = "studentXX-terraform-state-SUFFIX"   # Use actual bucket name from Lab 1 output
    key            = "pipeline/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "studentXX-terraform-lock-SUFFIX"    # Use actual table name from Lab 1 output
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      Student   = "studentXX"
      Purpose   = "Terraform Pipeline"
      ManagedBy = "Terraform"
    }
  }
}
```

Create `variables.tf`:

```hcl
# variables.tf
# Input variables for Lab 3 pipeline infrastructure

variable "student_id" {
  description = "Your student ID (e.g., student01)"
  type        = string
  default     = "studentXX"
}
```

> **Important:** Replace every occurrence of `studentXX` with your assigned student ID (e.g., `student01`). This includes the S3 backend bucket, DynamoDB table, and the default variable value. These resources were created in Lab 1.

### Step 3: Create CodeCommit Repository Configuration

Create `codecommit.tf`:

```hcl
# codecommit.tf - Source Repository

resource "aws_codecommit_repository" "terraform" {
  repository_name = "${var.student_id}-terraform-repo"
  description     = "Terraform code repository for ${var.student_id} - NovaTech pipeline"

  tags = {
    Name = "${var.student_id}-terraform-repo"
  }
}

output "repository_clone_url_http" {
  description = "HTTP clone URL for the repository"
  value       = aws_codecommit_repository.terraform.clone_url_http
}

output "repository_clone_url_ssh" {
  description = "SSH clone URL for the repository"
  value       = aws_codecommit_repository.terraform.clone_url_ssh
}

output "repository_arn" {
  description = "ARN of the CodeCommit repository"
  value       = aws_codecommit_repository.terraform.arn
}
```

### Step 4: Create IAM Roles and Policies

Create `iam.tf`:

```hcl
# iam.tf - IAM Roles for Pipeline Components

# =============================================================================
# CodeBuild Service Role
# =============================================================================
# This role is assumed by CodeBuild projects. It needs permissions to:
# - Write build logs to CloudWatch
# - Read/write state files in S3
# - Acquire/release DynamoDB state locks
# - Manage the AWS resources that Terraform will create (EC2, ELB, ASG, SSM)

resource "aws_iam_role" "codebuild" {
  name = "${var.student_id}-codebuild-terraform-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.student_id}-codebuild-terraform-role"
  }
}

resource "aws_iam_role_policy" "codebuild" {
  name = "${var.student_id}-codebuild-terraform-policy"
  role = aws_iam_role.codebuild.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      },
      {
        Sid    = "S3StateAndArtifacts"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.student_id}-terraform-state-*",       # Matches bucket with random suffix
          "arn:aws:s3:::${var.student_id}-terraform-state-*/*",     # Matches objects in bucket with random suffix
          "arn:aws:s3:::${var.student_id}-pipeline-artifacts",
          "arn:aws:s3:::${var.student_id}-pipeline-artifacts/*"
        ]
      },
      {
        Sid    = "DynamoDBStateLock"
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem"
        ]
        Resource = "arn:aws:dynamodb:*:*:table/${var.student_id}-terraform-lock-*"  # Matches table with random suffix
      },
      {
        Sid    = "TerraformManagedResources"
        Effect = "Allow"
        Action = [
          "ec2:*",
          "elasticloadbalancing:*",
          "autoscaling:*",
          "ssm:*"
        ]
        Resource = "*"
      }
    ]
  })
}

# =============================================================================
# CodePipeline Service Role
# =============================================================================
# This role is assumed by CodePipeline. It needs permissions to:
# - Pull source code from CodeCommit
# - Trigger and monitor CodeBuild projects
# - Read/write pipeline artifacts in S3

resource "aws_iam_role" "codepipeline" {
  name = "${var.student_id}-codepipeline-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codepipeline.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.student_id}-codepipeline-role"
  }
}

resource "aws_iam_role_policy" "codepipeline" {
  name = "${var.student_id}-codepipeline-policy"
  role = aws_iam_role.codepipeline.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CodeCommitAccess"
        Effect = "Allow"
        Action = [
          "codecommit:GetBranch",
          "codecommit:GetCommit",
          "codecommit:GetUploadArchiveStatus",
          "codecommit:UploadArchive",
          "codecommit:CancelUploadArchive"
        ]
        Resource = aws_codecommit_repository.terraform.arn
      },
      {
        Sid    = "CodeBuildAccess"
        Effect = "Allow"
        Action = [
          "codebuild:BatchGetBuilds",
          "codebuild:StartBuild"
        ]
        Resource = "*"
      },
      {
        Sid    = "S3ArtifactAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:GetBucketVersioning"
        ]
        Resource = [
          "arn:aws:s3:::${var.student_id}-pipeline-artifacts",
          "arn:aws:s3:::${var.student_id}-pipeline-artifacts/*"
        ]
      }
    ]
  })
}
```

> **Understanding the IAM design:** Notice the separation of concerns. The CodeBuild role has broad permissions because it executes Terraform, which needs to create and manage AWS resources. The CodePipeline role is narrower -- it only needs to orchestrate the flow between CodeCommit, CodeBuild, and S3. In production, you would scope the `TerraformManagedResources` statement to specific resource ARNs.

**Checkpoint:** You now have five files in `~/terraform-day3/lab3-pipeline/`:

```bash
ls -la ~/terraform-day3/lab3-pipeline/
# providers.tf
# variables.tf
# codecommit.tf
# iam.tf
```

Do not run `terraform apply` yet. You will deploy in stages in Parts B through D.

---

## Part B: Deploy Pipeline Foundation -- Stage 1 (15 min)

Deploying a complex pipeline all at once invites dependency errors. Instead, you will build the foundation first: the repository and IAM roles. These have no dependencies on other pipeline resources and must exist before CodeBuild projects can reference them.

### Step 5: Initialize Terraform

```bash
cd ~/terraform-day3/lab3-pipeline
terraform init
```

**Expected Output:**
```
Initializing the backend...

Successfully configured the backend "s3"! Terraform will automatically
use this backend unless the backend configuration changes.

Initializing provider plugins...
- Finding hashicorp/aws versions matching "~> 6.0"...
- Installing hashicorp/aws v6.x.x...

Terraform has been successfully initialized!
```

> **Note:** If you see "Error configuring S3 Backend," verify that your Lab 1 state bucket and DynamoDB table exist and that you replaced `studentXX` with your actual student ID.

### Step 6: Deploy Repository and IAM Roles

Use `-target` flags to deploy only the foundation resources:

```bash
terraform apply \
  -target=aws_codecommit_repository.terraform \
  -target=aws_iam_role.codebuild \
  -target=aws_iam_role_policy.codebuild \
  -target=aws_iam_role.codepipeline \
  -target=aws_iam_role_policy.codepipeline
```

Review the plan carefully. You should see **5 resources** to add:
- 1 CodeCommit repository
- 2 IAM roles (codebuild, codepipeline)
- 2 IAM role policies (codebuild, codepipeline)

Type `yes` to approve.

**Expected Output:**
```
Apply complete! Resources: 5 added, 0 changed, 0 destroyed.

Outputs:

repository_arn = "arn:aws:codecommit:us-east-1:XXXXXXXXXXXX:studentXX-terraform-repo"
repository_clone_url_http = "https://git-codecommit.us-east-1.amazonaws.com/v1/repos/studentXX-terraform-repo"
repository_clone_url_ssh = "ssh://git-codecommit.us-east-1.amazonaws.com/v1/repos/studentXX-terraform-repo"
```

> **Why staged deployment?** The `-target` flag tells Terraform to only plan and apply the specified resources (and their dependencies). This technique is essential when building complex infrastructure where some resources must exist before others can reference them. CodeBuild projects need the IAM role ARN, and CodePipeline needs the CodeCommit repository ARN.

### Step 7: Verify Foundation Resources

Verify the CodeCommit repository:

```bash
aws codecommit get-repository \
  --repository-name studentXX-terraform-repo \
  --query 'repositoryMetadata.{Name:repositoryName,ARN:Arn,CloneUrl:cloneUrlHttp}' \
  --output table
```

**Expected Output:**
```
---------------------------------------------------------------------
|                          GetRepository                            |
+----------+--------------------------------------------------------+
|  ARN     |  arn:aws:codecommit:us-east-1:XXXX:studentXX-...      |
|  CloneUrl|  https://git-codecommit.us-east-1.amazonaws.com/...    |
|  Name    |  studentXX-terraform-repo                              |
+----------+--------------------------------------------------------+
```

Verify the IAM roles:

```bash
aws iam get-role \
  --role-name studentXX-codebuild-terraform-role \
  --query 'Role.{Name:RoleName,ARN:Arn,Created:CreateDate}' \
  --output table

aws iam get-role \
  --role-name studentXX-codepipeline-role \
  --query 'Role.{Name:RoleName,ARN:Arn,Created:CreateDate}' \
  --output table
```

**Checkpoint:** Foundation is deployed. You have a CodeCommit repository and two IAM roles ready for CodeBuild and CodePipeline.

---

## Part C: Deploy Pipeline -- Stage 2: Build Projects (15 min)

Now you will create the five CodeBuild projects that perform the actual Terraform work. Each project uses an inline buildspec that defines the commands to execute. Pay close attention to the buildspec YAML -- these are the heart of your pipeline.

### Step 8: Create CodeBuild Projects

Create `codebuild.tf`:

```hcl
# codebuild.tf - CodeBuild Projects for Terraform Pipeline

# =============================================================================
# Artifacts Bucket
# =============================================================================
# Pipeline artifacts (source code, plan files) are stored here between stages

resource "aws_s3_bucket" "artifacts" {
  bucket = "${var.student_id}-pipeline-artifacts"

  tags = {
    Name = "${var.student_id}-pipeline-artifacts"
  }
}

resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}

# =============================================================================
# Project 1: Validate
# =============================================================================
# Runs terraform fmt -check and terraform validate on all code
# This catches formatting errors and syntax issues BEFORE any plan is generated

resource "aws_codebuild_project" "validate" {
  name          = "${var.student_id}-terraform-validate"
  description   = "Terraform format check and validate"
  service_role  = aws_iam_role.codebuild.arn
  build_timeout = 10

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "hashicorp/terraform:1.5"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = <<-EOF
      version: 0.2
      phases:
        install:
          commands:
            - terraform version
        build:
          commands:
            - echo "=== Running terraform fmt check ==="
            - terraform fmt -check -recursive
            - echo "=== Running terraform validate ==="
            - cd environments/staging
            - terraform init -backend=false
            - terraform validate
            - cd ../prod
            - terraform init -backend=false
            - terraform validate
            - echo "=== All validations passed ==="
    EOF
  }

  tags = {
    Name  = "${var.student_id}-terraform-validate"
    Stage = "validate"
  }
}

# =============================================================================
# Project 2: Plan Staging
# =============================================================================
# Generates a Terraform plan for the staging environment
# The plan file is saved as an artifact and passed to the apply stage

resource "aws_codebuild_project" "plan_staging" {
  name          = "${var.student_id}-terraform-plan-staging"
  description   = "Terraform plan for staging environment"
  service_role  = aws_iam_role.codebuild.arn
  build_timeout = 15

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "hashicorp/terraform:1.5"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"

    environment_variable {
      name  = "TF_VAR_environment"
      value = "staging"
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = <<-EOF
      version: 0.2
      phases:
        build:
          commands:
            - echo "=== Planning staging environment ==="
            - cd environments/staging
            - terraform init
            - terraform plan -out=tfplan
            - echo "=== Staging plan complete ==="
      artifacts:
        files:
          - environments/staging/tfplan
          - environments/staging/.terraform/**/*
          - environments/staging/.terraform.lock.hcl
          - modules/**/*
        base-directory: .
    EOF
  }

  tags = {
    Name        = "${var.student_id}-terraform-plan-staging"
    Stage       = "plan"
    Environment = "staging"
  }
}

# =============================================================================
# Project 3: Apply Staging
# =============================================================================
# Applies the previously generated plan to the staging environment
# Uses -auto-approve because the plan was already reviewed at the approval gate

resource "aws_codebuild_project" "apply_staging" {
  name          = "${var.student_id}-terraform-apply-staging"
  description   = "Terraform apply for staging environment"
  service_role  = aws_iam_role.codebuild.arn
  build_timeout = 30

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "hashicorp/terraform:1.5"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = <<-EOF
      version: 0.2
      phases:
        build:
          commands:
            - echo "=== Applying to staging environment ==="
            - cd environments/staging
            - terraform init
            - terraform apply -auto-approve tfplan
            - echo "=== Staging apply complete ==="
    EOF
  }

  tags = {
    Name        = "${var.student_id}-terraform-apply-staging"
    Stage       = "apply"
    Environment = "staging"
  }
}

# =============================================================================
# Project 4: Plan Production
# =============================================================================
# Generates a Terraform plan for the production environment
# Production uses us-west-2 region for geographic separation

resource "aws_codebuild_project" "plan_prod" {
  name          = "${var.student_id}-terraform-plan-prod"
  description   = "Terraform plan for production environment"
  service_role  = aws_iam_role.codebuild.arn
  build_timeout = 15

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "hashicorp/terraform:1.5"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"

    environment_variable {
      name  = "TF_VAR_environment"
      value = "prod"
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = <<-EOF
      version: 0.2
      phases:
        build:
          commands:
            - echo "=== Planning production environment ==="
            - cd environments/prod
            - terraform init
            - terraform plan -out=tfplan
            - echo "=== Production plan complete ==="
      artifacts:
        files:
          - environments/prod/tfplan
          - environments/prod/.terraform/**/*
          - environments/prod/.terraform.lock.hcl
          - modules/**/*
        base-directory: .
    EOF
  }

  tags = {
    Name        = "${var.student_id}-terraform-plan-prod"
    Stage       = "plan"
    Environment = "production"
  }
}

# =============================================================================
# Project 5: Apply Production
# =============================================================================
# Applies the previously generated plan to the production environment
# This is the final stage -- changes are now live in production

resource "aws_codebuild_project" "apply_prod" {
  name          = "${var.student_id}-terraform-apply-prod"
  description   = "Terraform apply for production environment"
  service_role  = aws_iam_role.codebuild.arn
  build_timeout = 30

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "hashicorp/terraform:1.5"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = <<-EOF
      version: 0.2
      phases:
        build:
          commands:
            - echo "=== Applying to production environment ==="
            - cd environments/prod
            - terraform init
            - terraform apply -auto-approve tfplan
            - echo "=== Production apply complete ==="
    EOF
  }

  tags = {
    Name        = "${var.student_id}-terraform-apply-prod"
    Stage       = "apply"
    Environment = "production"
  }
}
```

> **Understanding the buildspec structure:** Each buildspec follows the same pattern: `version: 0.2` declares the spec format, `phases.build.commands` lists the shell commands to execute, and `artifacts` (where present) defines which files to pass to the next stage. The plan stages produce a `tfplan` file as an artifact; the apply stages consume it.

### Step 9: Deploy CodeBuild Projects

```bash
terraform apply \
  -target=aws_s3_bucket.artifacts \
  -target=aws_s3_bucket_versioning.artifacts \
  -target=aws_codebuild_project.validate \
  -target=aws_codebuild_project.plan_staging \
  -target=aws_codebuild_project.apply_staging \
  -target=aws_codebuild_project.plan_prod \
  -target=aws_codebuild_project.apply_prod
```

Review the plan. You should see **7 resources** to add:
- 1 S3 bucket for artifacts
- 1 S3 bucket versioning configuration
- 5 CodeBuild projects

Type `yes` to approve.

**Expected Output:**
```
Apply complete! Resources: 7 added, 0 changed, 0 destroyed.
```

### Step 10: Verify Build Projects

Navigate to the AWS Console:

1. Go to **CodeBuild** -> **Build projects**
2. You should see five projects:

| Project Name | Purpose |
|---|---|
| `studentXX-terraform-validate` | Format checking and validation |
| `studentXX-terraform-plan-staging` | Generate staging plan |
| `studentXX-terraform-apply-staging` | Apply staging plan |
| `studentXX-terraform-plan-prod` | Generate production plan |
| `studentXX-terraform-apply-prod` | Apply production plan |

Click on any project and examine the **Build details** tab. You will see the inline buildspec, the IAM role, and the environment configuration.

Alternatively, verify from the CLI:

```bash
aws codebuild list-projects \
  --query 'projects[?contains(@, `studentXX`)]' \
  --output table
```

**Expected Output:**
```
--------------------------------------------------
|                  ListProjects                   |
+------------------------------------------------+
|  studentXX-terraform-apply-prod                |
|  studentXX-terraform-apply-staging             |
|  studentXX-terraform-plan-prod                 |
|  studentXX-terraform-plan-staging              |
|  studentXX-terraform-validate                  |
+------------------------------------------------+
```

**Checkpoint:** All five CodeBuild projects are deployed. The pipeline has its compute engine ready.

---

## Part D: Deploy Pipeline -- Stage 3: CodePipeline (10 min)

Now you bring everything together. The CodePipeline resource orchestrates the full workflow: pulling source from CodeCommit, triggering CodeBuild projects in sequence, and inserting approval gates between environments.

### Step 11: Create CodePipeline Configuration

Create `codepipeline.tf`:

```hcl
# codepipeline.tf - Pipeline Definition
# Orchestrates the full Terraform deployment workflow across environments

resource "aws_codepipeline" "terraform" {
  name     = "${var.student_id}-terraform-pipeline"
  role_arn = aws_iam_role.codepipeline.arn

  artifact_store {
    location = aws_s3_bucket.artifacts.bucket
    type     = "S3"
  }

  # =========================================================================
  # Stage 1: Source
  # =========================================================================
  # Triggers automatically when code is pushed to the main branch

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeCommit"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        RepositoryName = aws_codecommit_repository.terraform.repository_name
        BranchName     = "main"
      }
    }
  }

  # =========================================================================
  # Stage 2: Validate
  # =========================================================================
  # Runs fmt check and validate on all Terraform code

  stage {
    name = "Validate"

    action {
      name             = "Terraform-Validate"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["validate_output"]
      version          = "1"

      configuration = {
        ProjectName = aws_codebuild_project.validate.name
      }
    }
  }

  # =========================================================================
  # Stage 3: Plan Staging
  # =========================================================================
  # Generates a Terraform plan for staging; plan file becomes an artifact

  stage {
    name = "Plan-Staging"

    action {
      name             = "Terraform-Plan-Staging"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["staging_plan_output"]
      version          = "1"

      configuration = {
        ProjectName = aws_codebuild_project.plan_staging.name
      }
    }
  }

  # =========================================================================
  # Stage 4: Approve Staging
  # =========================================================================
  # Manual approval gate - reviewer must approve before staging deploy

  stage {
    name = "Approve-Staging"

    action {
      name     = "Approve-Staging-Deploy"
      category = "Approval"
      owner    = "AWS"
      provider = "Manual"
      version  = "1"

      configuration = {
        CustomData = "Review the Terraform plan for STAGING and approve to deploy. Check the Plan-Staging build logs for details."
      }
    }
  }

  # =========================================================================
  # Stage 5: Apply Staging
  # =========================================================================
  # Applies the approved plan to staging environment (us-east-1)

  stage {
    name = "Apply-Staging"

    action {
      name            = "Terraform-Apply-Staging"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      input_artifacts = ["staging_plan_output"]
      version         = "1"

      configuration = {
        ProjectName = aws_codebuild_project.apply_staging.name
      }
    }
  }

  # =========================================================================
  # Stage 6: Plan Production
  # =========================================================================
  # Generates a Terraform plan for production; uses source_output (not staging)

  stage {
    name = "Plan-Production"

    action {
      name             = "Terraform-Plan-Prod"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["prod_plan_output"]
      version          = "1"

      configuration = {
        ProjectName = aws_codebuild_project.plan_prod.name
      }
    }
  }

  # =========================================================================
  # Stage 7: Approve Production
  # =========================================================================
  # Manual approval gate - PRODUCTION requires careful review

  stage {
    name = "Approve-Production"

    action {
      name     = "Approve-Production-Deploy"
      category = "Approval"
      owner    = "AWS"
      provider = "Manual"
      version  = "1"

      configuration = {
        CustomData = "PRODUCTION DEPLOYMENT - Review the production plan carefully before approving. This will modify live infrastructure."
      }
    }
  }

  # =========================================================================
  # Stage 8: Apply Production
  # =========================================================================
  # Applies the approved plan to production environment (us-west-2)

  stage {
    name = "Apply-Production"

    action {
      name            = "Terraform-Apply-Prod"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      input_artifacts = ["prod_plan_output"]
      version         = "1"

      configuration = {
        ProjectName = aws_codebuild_project.apply_prod.name
      }
    }
  }

  tags = {
    Name = "${var.student_id}-terraform-pipeline"
  }
}

output "pipeline_name" {
  description = "Name of the CodePipeline"
  value       = aws_codepipeline.terraform.name
}

output "pipeline_arn" {
  description = "ARN of the CodePipeline"
  value       = aws_codepipeline.terraform.arn
}
```

### Step 12: Deploy the Complete Pipeline

Now deploy everything -- no `-target` flags this time. Terraform will create only the remaining resources (the CodePipeline itself) since the foundation and build projects already exist.

```bash
terraform apply
```

Review the plan. You should see **1 resource** to add (the `aws_codepipeline.terraform` resource). All previously deployed resources should show "no changes."

Type `yes` to approve.

**Expected Output:**
```
Apply complete! Resources: 1 added, 0 changed, 0 destroyed.

Outputs:

pipeline_arn = "arn:aws:codepipeline:us-east-1:XXXXXXXXXXXX:studentXX-terraform-pipeline"
pipeline_name = "studentXX-terraform-pipeline"
repository_arn = "arn:aws:codecommit:us-east-1:XXXXXXXXXXXX:studentXX-terraform-repo"
repository_clone_url_http = "https://git-codecommit.us-east-1.amazonaws.com/v1/repos/studentXX-terraform-repo"
repository_clone_url_ssh = "ssh://git-codecommit.us-east-1.amazonaws.com/v1/repos/studentXX-terraform-repo"
```

### Step 13: View Pipeline Visualization in AWS Console

1. Navigate to **AWS Console** -> **CodePipeline** -> **Pipelines**
2. Click on `studentXX-terraform-pipeline`
3. You will see the full 8-stage pipeline visualization

The pipeline will be in a **Failed** state on the Source stage -- this is expected. The CodeCommit repository is empty. There is no code to pull yet.

Take a moment to examine the visualization. Each stage is a box. The approval stages have a "Review" button. The build stages link to their CodeBuild project logs. This is the automated workflow that replaces "running apply from my laptop."

**Checkpoint:** The full pipeline is deployed and visible in the Console. Next, you will push code through it.

---

## Part E: Push Application Code to Pipeline (15 min)

The pipeline infrastructure is complete. Now you need to give it something to deploy. You will create a simple Terraform application with staging and production environments, push it to CodeCommit, and watch the pipeline execute.

### Step 14: Clone the CodeCommit Repository

```bash
cd ~/terraform-day3

# Get the HTTP clone URL from Terraform output
terraform -chdir=lab3-pipeline output repository_clone_url_http
```

Before cloning, configure the Git credential helper for CodeCommit:

```bash
git config --global credential.helper '!aws codecommit credential-helper $@'
git config --global credential.UseHttpPath true
```

Now clone the empty repository:

```bash
git clone $(terraform -chdir=lab3-pipeline output -raw repository_clone_url_http) app-repo
cd app-repo
```

> **Note:** If you receive a warning about cloning an empty repository, that is expected. The repository was just created and has no commits yet.

### Step 15: Create Directory Structure

```bash
mkdir -p environments/staging environments/prod modules/app
```

Your directory structure will look like this:

```
app-repo/
  environments/
    staging/
      main.tf
    prod/
      main.tf
  modules/
    app/
      main.tf
      variables.tf
```

### Step 16: Create the Shared Application Module

Create `modules/app/variables.tf`:

```hcl
# variables.tf
# Input variables for the shared application module

variable "environment" {
  description = "Environment name (staging, prod)"
  type        = string
}

variable "student_id" {
  description = "Student identifier for resource namespacing"
  type        = string
}

variable "instance_count" {
  description = "Number of application instances (stored as config)"
  type        = number
  default     = 2
}
```

Create `modules/app/main.tf`:

```hcl
# modules/app/main.tf - Shared application module
# This module defines the application configuration for any environment.
# It uses SSM Parameter Store to demonstrate real infrastructure changes
# flowing through the pipeline without incurring significant costs.

resource "aws_ssm_parameter" "app_config" {
  name        = "/${var.student_id}/${var.environment}/app-config"
  description = "Application configuration for ${var.environment}"
  type        = "String"
  value       = "environment=${var.environment},instances=${var.instance_count},version=1.0.0"

  tags = {
    Name        = "${var.student_id}-${var.environment}-config"
    Environment = var.environment
    Student     = var.student_id
  }
}

resource "aws_ssm_parameter" "deploy_timestamp" {
  name        = "/${var.student_id}/${var.environment}/last-deploy"
  description = "Timestamp of last deployment to ${var.environment}"
  type        = "String"
  value       = timestamp()

  tags = {
    Name        = "${var.student_id}-${var.environment}-deploy-timestamp"
    Environment = var.environment
    Student     = var.student_id
  }

  lifecycle {
    ignore_changes = [value]
  }
}

output "config_parameter_name" {
  description = "Name of the application config parameter"
  value       = aws_ssm_parameter.app_config.name
}

output "config_parameter_value" {
  description = "Value of the application config parameter"
  value       = aws_ssm_parameter.app_config.value
}
```

> **Why SSM Parameters?** In a real pipeline, you would deploy EC2 instances, load balancers, and Auto Scaling Groups. For this lab, we use SSM Parameter Store because it creates real AWS resources that are fast to deploy, free, and easy to verify. The pipeline workflow is identical regardless of what Terraform manages.

### Step 17: Create Staging Environment Configuration

Create `environments/staging/main.tf`:

```hcl
# environments/staging/main.tf - Staging environment
# Deployed to us-east-1 via the pipeline
# NOTE: Use the bucket and table names from your Lab 1 terraform output

terraform {
  required_version = ">= 1.5.0"

  backend "s3" {
    bucket         = "studentXX-terraform-state-SUFFIX"   # Use actual bucket name from Lab 1 output
    key            = "pipeline/staging/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "studentXX-terraform-lock-SUFFIX"    # Use actual table name from Lab 1 output
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      Student     = "studentXX"
      Environment = "staging"
      ManagedBy   = "Terraform-Pipeline"
    }
  }
}

module "app" {
  source         = "../../modules/app"
  environment    = "staging"
  student_id     = "studentXX"
  instance_count = 2
}

output "config_parameter" {
  description = "Staging config parameter name"
  value       = module.app.config_parameter_name
}

output "config_value" {
  description = "Staging config parameter value"
  value       = module.app.config_parameter_value
}
```

### Step 18: Create Production Environment Configuration

Create `environments/prod/main.tf`:

```hcl
# environments/prod/main.tf - Production environment
# Deployed to us-west-2 via the pipeline (geographic separation from staging)
# NOTE: Use the bucket and table names from your Lab 1 terraform output

terraform {
  required_version = ">= 1.5.0"

  backend "s3" {
    bucket         = "studentXX-terraform-state-SUFFIX"   # Use actual bucket name from Lab 1 output
    key            = "pipeline/prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "studentXX-terraform-lock-SUFFIX"    # Use actual table name from Lab 1 output
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "us-west-2"

  default_tags {
    tags = {
      Student     = "studentXX"
      Environment = "production"
      ManagedBy   = "Terraform-Pipeline"
    }
  }
}

module "app" {
  source         = "../../modules/app"
  environment    = "prod"
  student_id     = "studentXX"
  instance_count = 3
}

output "config_parameter" {
  description = "Production config parameter name"
  value       = module.app.config_parameter_name
}

output "config_value" {
  description = "Production config parameter value"
  value       = module.app.config_parameter_value
}
```

> **Notice the differences between staging and production:**
> - **Region:** Staging uses `us-east-1`, production uses `us-west-2`
> - **State path:** Different `key` values in the backend block ensure separate state files
> - **Instance count:** Staging runs 2 instances, production runs 3
> - These are the kinds of environment-specific values that flow through your pipeline

### Step 19: Commit and Push to CodeCommit

```bash
cd ~/terraform-day3/app-repo

# Verify your files are in place
find . -name "*.tf" -type f

# Stage all files
git add .

# Commit
git commit -m "Initial Terraform configuration - staging and production environments"

# Push to main branch
git push origin main
```

**Expected Output:**
```
Enumerating objects: 10, done.
Counting objects: 100% (10/10), done.
Delta compression using up to 4 threads
Compressing objects: 100% (8/8), done.
Writing objects: 100% (10/10), 2.XX KiB | X.XX MiB/s, done.
Total 10 (delta 0), reused 0 (delta 0)
To https://git-codecommit.us-east-1.amazonaws.com/v1/repos/studentXX-terraform-repo
 * [new branch]      main -> main
```

### Step 20: Watch the Pipeline Execute

1. Navigate to **AWS Console** -> **CodePipeline** -> **Pipelines**
2. Click on `studentXX-terraform-pipeline`
3. Watch the pipeline progress:

| Stage | Expected Result | Action Required |
|---|---|---|
| Source | Succeeds automatically (pulls code from CodeCommit) | None |
| Validate | Succeeds if `terraform fmt` and `validate` pass | None |
| Plan-Staging | Succeeds and generates a plan file | None |
| **Approve-Staging** | **Pauses and waits for approval** | **Click "Review" then "Approve"** |
| Apply-Staging | Applies the plan to staging | None |
| Plan-Production | Generates production plan | None |
| **Approve-Production** | **Pauses and waits for approval** | **Click "Review" then "Approve"** |
| Apply-Production | Applies the plan to production | None |

**To approve a stage:**
1. When the pipeline reaches an approval stage, the stage will show "Review" as a clickable action
2. Click **Review**
3. Optionally add a comment (e.g., "Reviewed staging plan - 2 resources to create")
4. Click **Approve**

> **This is Jordan's mandate in action.** No human runs `terraform apply`. The pipeline runs it. Humans only review and approve. The plan output, the approval decision, and the apply result are all recorded -- creating the audit trail the CTO demanded.

Wait for the pipeline to complete all stages. This will take several minutes as each CodeBuild project initializes a container and runs Terraform.

**Checkpoint:** Your first commit has been deployed to both staging and production through the automated pipeline.

---

## Part F: Make a Change & Promote (10 min)

This is the real test. Jordan's team needs to scale staging from 2 instances to 4. Instead of SSH-ing into the staging environment and running Terraform manually, they commit the change and let the pipeline handle everything.

### Step 21: Edit the Staging Configuration

```bash
cd ~/terraform-day3/app-repo
```

Edit `environments/staging/main.tf` and change `instance_count` from `2` to `4`:

```bash
sed -i 's/instance_count = 2/instance_count = 4/' environments/staging/main.tf
```

Verify the change:

```bash
grep instance_count environments/staging/main.tf
```

**Expected Output:**
```
  instance_count = 4
```

### Step 22: Commit and Push the Change

```bash
git add environments/staging/main.tf
git commit -m "Scale staging to 4 instances"
git push origin main
```

### Step 23: Watch the Pipeline Trigger Automatically

1. Navigate to **AWS Console** -> **CodePipeline** -> **Pipelines**
2. Click on `studentXX-terraform-pipeline`
3. The pipeline should trigger automatically within 1-2 minutes

> **Key observation:** You did not trigger this pipeline manually. CodePipeline detected the new commit on the `main` branch and started automatically. This is the event-driven workflow that replaces manual deployments.

Watch the pipeline progress through the stages. When it reaches the Plan-Staging stage, click on the **Details** link to view the CodeBuild logs. You should see Terraform's plan output showing the SSM parameter value changing.

### Step 24: Approve Staging and Production

1. When the pipeline reaches **Approve-Staging**, click **Review** -> **Approve**
   - Comment: "Reviewed - staging scaling from 2 to 4 instances"
2. Wait for Apply-Staging to complete
3. When the pipeline reaches **Approve-Production**, click **Review** -> **Approve**
   - Comment: "Approved - production unchanged, staging change only"

> **Notice:** The production plan should show no changes (or minimal changes) because you only modified the staging configuration. In a real pipeline, this is exactly the behavior you want -- changes to one environment do not accidentally affect another.

### Step 25: Verify Deployments with AWS CLI

Verify the staging configuration was updated:

```bash
aws ssm get-parameter \
  --name "/studentXX/staging/app-config" \
  --region us-east-1 \
  --query 'Parameter.{Name:Name,Value:Value,LastModified:LastModifiedDate}' \
  --output table
```

**Expected Output:**
```
-------------------------------------------------------------
|                        GetParameter                       |
+--------------+--------------------------------------------+
|  LastModified|  2024-XX-XXTXX:XX:XX.XXXXXXX+00:00        |
|  Name        |  /studentXX/staging/app-config              |
|  Value       |  environment=staging,instances=4,version=... |
+--------------+--------------------------------------------+
```

Verify the production configuration:

```bash
aws ssm get-parameter \
  --name "/studentXX/prod/app-config" \
  --region us-west-2 \
  --query 'Parameter.{Name:Name,Value:Value,LastModified:LastModifiedDate}' \
  --output table
```

**Expected Output:**
```
-------------------------------------------------------------
|                        GetParameter                       |
+--------------+--------------------------------------------+
|  LastModified|  2024-XX-XXTXX:XX:XX.XXXXXXX+00:00        |
|  Name        |  /studentXX/prod/app-config                 |
|  Value       |  environment=prod,instances=3,version=...    |
+--------------+--------------------------------------------+
```

The staging value shows `instances=4` (updated), while production shows `instances=3` (unchanged). The pipeline correctly promoted the change to staging and left production unmodified.

**Checkpoint:** You have successfully pushed a change through the complete pipeline lifecycle -- from git commit to verified deployment.

---

## Troubleshooting

### Issue 1: CodeCommit Authentication Fails

**Symptoms:** `git push` returns `403 Forbidden` or prompts for username/password

**Solution:** Configure the AWS credential helper for CodeCommit:

```bash
# Configure Git to use the AWS CLI credential helper
git config --global credential.helper '!aws codecommit credential-helper $@'
git config --global credential.UseHttpPath true

# Verify your AWS identity
aws sts get-caller-identity
```

If you are using AWS SSO or temporary credentials, ensure your session is active:

```bash
aws sso login --profile your-profile
```

### Issue 2: Pipeline Fails on Validate Stage

**Symptoms:** Validate stage shows red/failed; build logs show `terraform fmt` errors

**Solution:** Terraform fmt is strict. Fix formatting before pushing:

```bash
# Check formatting locally
cd ~/terraform-day3/app-repo
terraform fmt -check -recursive

# Auto-fix formatting
terraform fmt -recursive

# Re-commit and push
git add .
git commit -m "Fix terraform formatting"
git push origin main
```

Common formatting issues:
- Incorrect indentation (tabs vs. spaces)
- Missing newline at end of file
- Inconsistent alignment of `=` signs

### Issue 3: Apply Stage Fails with Permission Error

**Symptoms:** Apply stage fails; build logs show `AccessDeniedException` or `UnauthorizedAccess`

**Solution:** The CodeBuild IAM role may lack permissions for the resources Terraform is trying to create. Check the build logs for the specific permission error:

```bash
# View recent build logs
aws codebuild list-builds-for-project \
  --project-name studentXX-terraform-apply-staging \
  --query 'ids[0]' --output text | xargs -I {} \
  aws codebuild batch-get-builds --ids {} \
  --query 'builds[0].phases[?phaseType==`BUILD`].contexts[0].message' \
  --output text
```

If the error relates to a specific AWS service, add the required permissions to the `aws_iam_role_policy.codebuild` policy in `iam.tf` and redeploy.

### Issue 4: Pipeline Stuck Waiting for Approval

**Symptoms:** Pipeline shows "In Progress" on an approval stage but you cannot find the approval button

**Solution:**

1. Navigate to **AWS Console** -> **CodePipeline** -> **Pipelines**
2. Click on your pipeline name
3. Scroll down to the approval stage (it may be below the fold)
4. Click the **Review** button on the approval action
5. Enter an optional comment and click **Approve** (or **Reject**)

Approval actions have a default timeout of 7 days. If the pipeline has been waiting longer than that, it will fail and you will need to trigger a new execution by pushing another commit or clicking **Release change** at the top of the pipeline view.

### Issue 5: CodeBuild Timeout

**Symptoms:** Build stage fails with "Build timed out" message

**Solution:** The default `build_timeout` in the CodeBuild project may be too short. Increase it in `codebuild.tf`:

```hcl
# Change from:
build_timeout = 10

# Change to:
build_timeout = 20
```

Then redeploy:

```bash
cd ~/terraform-day3/lab3-pipeline
terraform apply
```

Typical build times:
- Validate: 2-3 minutes (increase to 10-15 if slow)
- Plan: 3-5 minutes (increase to 15-20 if slow)
- Apply: 5-10 minutes (increase to 30 if slow)

---

## Knowledge Check

**Question 1:** Why does the pipeline use separate "Plan" and "Apply" stages with an approval gate between them, rather than a single stage that runs `terraform plan` followed by `terraform apply`?

*Answer:* The separation ensures that a human reviewer can inspect the exact changes Terraform intends to make before they are applied. The plan stage generates a plan file (`tfplan`) as an artifact, and the apply stage uses that exact file. This guarantees that the changes applied are identical to the changes reviewed -- no drift can occur between the plan and the apply. If they were in a single stage, the plan output would scroll by in build logs with no opportunity for review, and there would be no audit record of approval.

**Question 2:** In the pipeline architecture, the Plan-Production stage uses `source_output` as its input artifact rather than `staging_plan_output`. Why?

*Answer:* The production plan needs the original source code (the Terraform configuration files), not the staging plan file. Each environment has its own backend configuration, provider settings, and variable values. The staging plan file (`tfplan`) is specific to the staging state and cannot be applied to production. By using `source_output`, the production plan stage runs `terraform init` and `terraform plan` against the production backend, generating a production-specific plan. This is a critical design pattern: each environment gets its own plan generated from the same source code.

**Question 3:** What would happen if an engineer bypassed the pipeline and ran `terraform apply` directly against the production environment from their laptop?

*Answer:* Technically, it would work if they had the correct AWS credentials and backend configuration. This is why the CTO's mandate requires more than just a pipeline -- it requires IAM policy enforcement. In a production setup, you would restrict the IAM permissions so that only the CodeBuild role (assumed by the pipeline) can run Terraform operations against production state. Individual engineers would have read-only access to production. The pipeline enforces the workflow; IAM enforces the access control. Together, they make the mandate "no human runs apply against production" technically enforceable.

**Question 4:** The CodeBuild environment uses `image = "hashicorp/terraform:1.5"`. What risk does this create, and how would you mitigate it in a production pipeline?

*Answer:* The tag `1.5` resolves to the latest `1.5.x` patch version at the time the container is pulled. This means different pipeline executions could use different Terraform patch versions (e.g., 1.5.6 vs. 1.5.7), potentially introducing inconsistencies. In production, you should pin to a specific version (e.g., `hashicorp/terraform:1.5.7`) or build a custom container image with your exact Terraform version, pre-installed providers, and any other tools your pipeline needs. You would store that image in Amazon ECR and reference it from CodeBuild.

---

## Lab Completion Checklist

Verify that each item is complete before moving on:

- [ ] Working directory `~/terraform-day3/lab3-pipeline` contains all six `.tf` files (providers.tf, variables.tf, codecommit.tf, iam.tf, codebuild.tf, codepipeline.tf)
- [ ] `terraform init` succeeded with S3 backend
- [ ] CodeCommit repository `studentXX-terraform-repo` exists and is accessible
- [ ] IAM role `studentXX-codebuild-terraform-role` exists with correct policy
- [ ] IAM role `studentXX-codepipeline-role` exists with correct policy
- [ ] S3 artifacts bucket `studentXX-pipeline-artifacts` exists with versioning enabled
- [ ] CodeBuild project `studentXX-terraform-validate` exists
- [ ] CodeBuild project `studentXX-terraform-plan-staging` exists
- [ ] CodeBuild project `studentXX-terraform-apply-staging` exists
- [ ] CodeBuild project `studentXX-terraform-plan-prod` exists
- [ ] CodeBuild project `studentXX-terraform-apply-prod` exists
- [ ] CodePipeline `studentXX-terraform-pipeline` exists with 8 stages
- [ ] Application code pushed to CodeCommit repository
- [ ] Pipeline executed successfully on initial push (all stages green)
- [ ] Staging SSM parameter `/studentXX/staging/app-config` shows `instances=4`
- [ ] Production SSM parameter `/studentXX/prod/app-config` shows `instances=3`
- [ ] Second pipeline execution triggered automatically by the scaling commit

---

## Cost Considerations

**What This Lab Created:**

| Resource | Description | Estimated Cost |
|----------|-------------|----------------|
| CodeCommit Repository | 1 repository, < 5 users | Free (first 5 active users) |
| CodeBuild Projects | 5 projects, ~100 build minutes | Free (100 min/month free tier) |
| CodePipeline | 1 pipeline | $1.00/pipeline/month (free first 30 days) |
| S3 Artifacts Bucket | Pipeline artifact storage | < $0.01/month |
| S3 State Storage | Terraform state files | < $0.01/month |
| SSM Parameters | 4 parameters (2 per environment) | Free (standard tier) |
| IAM Roles | 2 roles with policies | Free |

**Total estimated cost:** Less than $1.10/month after free tier.

**Cleanup (if not continuing to Lab 4):**

```bash
# First, destroy the application resources created by the pipeline
cd ~/terraform-day3/app-repo/environments/staging
terraform init
terraform destroy -auto-approve

cd ~/terraform-day3/app-repo/environments/prod
terraform init
terraform destroy -auto-approve

# Then destroy the pipeline infrastructure
cd ~/terraform-day3/lab3-pipeline
terraform destroy
```

> **Warning:** Destroy the application resources (SSM parameters) first, then the pipeline infrastructure. If you destroy the pipeline first, you lose the ability to manage application resources through the pipeline and must clean them up manually.

**Cost Optimization Tips:**
- CodeBuild charges only for build minutes consumed, not idle time
- Use `BUILD_GENERAL1_SMALL` (the default in this lab) for the cheapest compute tier
- Set aggressive `build_timeout` values to prevent runaway builds from consuming minutes
- Delete pipelines you are no longer using -- the $1/month charge is per active pipeline

---

## Next Steps

In **Lab 4: Auditing & Observability**, you will build the monitoring layer that answers the compliance team's questions: "Who deployed what, and when?" You will configure CloudTrail queries to trace pipeline executions, build a CloudWatch dashboard showing deployment history and pipeline health, and create the audit trail that proves your infrastructure changes match what is in version control.

**Keep your pipeline infrastructure running -- Lab 4 builds on it!**

---

## Additional Resources

- [AWS CodePipeline User Guide](https://docs.aws.amazon.com/codepipeline/latest/userguide/) - *Source: AWS Docs*
- [AWS CodeBuild User Guide](https://docs.aws.amazon.com/codebuild/latest/userguide/) - *Source: AWS Docs*
- [AWS CodeCommit User Guide](https://docs.aws.amazon.com/codecommit/latest/userguide/) - *Source: AWS Docs*
- [Terraform CI/CD Best Practices](https://developer.hashicorp.com/terraform/tutorials/automation) - *Source: HashiCorp Learn*
- [Buildspec Reference for CodeBuild](https://docs.aws.amazon.com/codebuild/latest/userguide/build-spec-ref.html) - *Source: AWS Docs*
- [Terraform Backend Configuration: S3](https://developer.hashicorp.com/terraform/language/settings/backends/s3) - *Source: HashiCorp Docs*
