# 🚀 Production-Ready Amazon EKS with Terraform & GitHub Actions

![EKS - GitHub Actions - Terraform](assets/Presentation1.gif)

## 📖 Overview

This project demonstrates how to provision a **production-ready Amazon EKS (Elastic Kubernetes Service)** cluster using **Terraform** and automate infrastructure deployments through **GitHub Actions**.

The solution follows Infrastructure as Code (IaC) principles and modern CI/CD practices using GitHub-hosted runners and AWS authentication via OpenID Connect (OIDC).

---

## ✨ Features

* Infrastructure as Code (IaC) using Terraform
* Amazon EKS Cluster Deployment
* GitHub Actions CI/CD Pipeline
* GitHub OIDC Authentication
* Remote Terraform State (Amazon S3)
* Terraform State Locking (Amazon DynamoDB)
* Bastion Host Configuration
* AWS Systems Manager (SSM) Session Manager
* Production-ready modular Terraform structure

---

## 🛠️ Technology Stack

* Terraform
* Amazon EKS
* Amazon VPC
* IAM
* Amazon EC2
* Amazon S3
* Amazon DynamoDB
* GitHub Actions
* GitHub OIDC
* AWS CLI
* kubectl
* AWS Systems Manager (SSM)

---

## 📂 Repository Structure

```text
.
├── .github
│   └── workflows
│       └── terraform-eks.yml
├── assets
│   └── Presentation1.gif
├── backend.tf
├── provider.tf
├── versions.tf
├── main.tf
├── variables.tf
├── outputs.tf
├── dev.tfvars
├── prod.tfvars
├── modules
│   ├── vpc
│   ├── eks
│   ├── iam
│   └── bastion
└── README.md
```

---

# 🔐 GitHub-Hosted Runner with AWS OIDC Flow

When using **GitHub-hosted runners**, the runners are ephemeral and **do not have AWS credentials** by default.

Instead of storing AWS Access Keys in GitHub Secrets, the workflow authenticates using **GitHub OpenID Connect (OIDC)** and assumes an AWS IAM Role.

This approach follows AWS security best practices.

---

## Architecture

```text
GitHub Workflow
       │
       ▼
GitHub Hosted Runner
       │
       │ Request OIDC Token
       ▼
GitHub OIDC Provider
       │
       ▼
AWS IAM Role
       │
       │ AssumeRoleWithWebIdentity
       ▼
Temporary AWS Credentials
       │
       ▼
AWS Resources
(EKS, S3, ECR, IAM, DynamoDB)
```

---

## Authentication Flow

### Step 1 – Workflow Execution

The GitHub Actions workflow starts on a GitHub-hosted runner.

The runner has **no AWS credentials** initially.

---

### Step 2 – Request OIDC Token

The runner requests an identity token from GitHub.

The token contains claims such as:

* Audience (`aud`)
* Repository (`sub`)
* Branch
* Workflow

---

### Step 3 – Assume IAM Role

AWS validates the OIDC token and allows the runner to assume the configured IAM Role.

Example IAM Trust Policy:

```json
{
  "Effect": "Allow",
  "Principal": {
    "Federated": "arn:aws:iam::<account-id>:oidc-provider/token.actions.githubusercontent.com"
  },
  "Action": "sts:AssumeRoleWithWebIdentity",
  "Condition": {
    "StringEquals": {
      "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
      "token.actions.githubusercontent.com:sub": "repo:username/repository:ref:refs/heads/main"
    }
  }
}
```

---

### Step 4 – Temporary Credentials

AWS Security Token Service (STS) issues temporary credentials.

These credentials include:

* Access Key
* Secret Access Key
* Session Token

The credentials are valid only for a limited duration.

---

### Step 5 – Access AWS Resources

Terraform uses the temporary credentials to provision AWS infrastructure such as:

* Amazon EKS
* Amazon VPC
* IAM Roles
* Amazon S3
* Amazon DynamoDB

---

## Verify Authentication

GitHub Actions example:

```yaml
steps:
  - name: Configure AWS Credentials
    uses: aws-actions/configure-aws-credentials@v5
    with:
      role-to-assume: arn:aws:iam::<account-id>:role/github-oidc-role
      aws-region: us-east-1

  - name: Verify AWS Identity
    run: aws sts get-caller-identity
```

Expected Output:

```json
{
  "Arn": "arn:aws:iam::<account-id>:role/github-oidc-role",
  "Account": "<account-id>"
}
```

---

## GitHub Hosted vs Self Hosted Runner

| Feature        | GitHub Hosted Runner | Self Hosted Runner       |
| -------------- | -------------------- | ------------------------ |
| Location       | GitHub Cloud         | Customer Managed         |
| Authentication | OIDC                 | IAM Role / Access Keys   |
| Credentials    | Temporary            | Long-lived or IAM Role   |
| Security       | High                 | Depends on configuration |
| Maintenance    | None                 | User Managed             |

---

# 📦 Terraform Remote Backend

Terraform state is stored remotely using:

* Amazon S3 Bucket
* Amazon DynamoDB for State Locking

### Benefits

* Shared Terraform State
* Prevents concurrent modifications
* State Versioning
* Team Collaboration
* Secure Remote Storage

---

# 🚀 Deployment Workflow

```text
Developer
     │
     ▼
GitHub Push
     │
     ▼
GitHub Actions
     │
     ▼
Terraform Init
     │
     ▼
Terraform Validate
     │
     ▼
Terraform Plan
     │
     ▼
Terraform Apply
     │
     ▼
Amazon EKS Cluster
```

---

# 🛡️ Bastion Host Setup (SSH + AWS SSM)

This project supports two methods for accessing EC2 instances.

## Option 1 – SSH using Key Pair

Traditional SSH access through a Bastion Host.

---

## Option 2 – AWS Systems Manager (Recommended)

Benefits:

* No Public SSH Access
* No Key Pair Management
* IAM Controlled Access
* CloudTrail Auditing
* Enhanced Security

---

## Architecture

```text
Developer Laptop
       │
       │ SSH / SSM
       ▼
Bastion Host (Public Subnet)
       │
       ▼
Private EC2 Instance
```

---

## IAM Role for SSM

```hcl
resource "aws_iam_role" "ec2_ssm_role" {
  name = "ec2-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_attach" {
  role       = aws_iam_role.ec2_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
```

---

## Bastion Security Group

Only outbound traffic is required.

```hcl
egress {
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]
}
```

No inbound rules are required when using AWS Systems Manager.

---

## Connect Using AWS CLI

```bash
aws ssm start-session --target <instance-id>
```

---

## Troubleshooting

### SSH Issues

Verify:

* Public IP
* Security Group allows port 22
* Correct Key Pair
* Correct SSH username

---

### Session Manager Issues

Verify:

* IAM Role attached
* AmazonSSMManagedInstanceCore policy attached
* SSM Agent is running
* Internet access or VPC Endpoints available

```bash
sudo systemctl status amazon-ssm-agent
```

---

# ▶️ Deploy Infrastructure

Initialize Terraform:

```bash
terraform init
```

Validate configuration:

```bash
terraform validate
```

Generate execution plan:

```bash
terraform plan -var-file=dev.tfvars
```

Deploy infrastructure:

```bash
terraform apply -var-file=dev.tfvars
```

---

# 🧹 Destroy Infrastructure

```bash
terraform destroy -var-file=dev.tfvars
```

---

# 📸 Demo

![EKS Deployment](assets/Presentation1.gif)

---

# 📚 References

* Terraform Documentation
* Amazon EKS Documentation
* GitHub Actions Documentation
* AWS IAM OIDC Documentation
* AWS Systems Manager Documentation
