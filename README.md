# 🚀 Configuring Production-Ready EKS Clusters with Terraform and GitHub Actions


![EKS- GitHub Actions- Terraform](assets/Presentation1.gif)

## 🌟 Overview
This project covers:
- **Infrastructure as Code (IaC)**: Use Terraform to define and manage your EKS cluster.
- **CI/CD Automation**: Leverage GitHub Actions to automate deployments.
# GitHub-Hosted Runner with AWS OIDC Flow




This document explains the authentication flow for **GitHub-hosted runners** accessing AWS resources via **OIDC (OpenID Connect)**.

---

## Overview

When using **GitHub-hosted runners**, the runners are ephemeral and **do not have AWS credentials** by default.  
To authenticate with AWS, the runner uses an **OIDC token issued by GitHub** to assume a specific **IAM role**.

---

## Architecture Diagram

``` bash

GitHub Workflow (cloud)
│
▼
GitHub-Hosted Runner (ephemeral)
│
│ Requests OIDC token from GitHub
▼
GitHub OIDC Token
│
▼
AWS IAM Role (Trusts GitHub OIDC)
│
│ sts:AssumeRoleWithWebIdentity
▼
AWS Temporary Credentials
│
▼
AWS Resources (EKS, S3, ECR, etc.)

````

---

## Step-by-Step Flow

1. **GitHub Workflow Execution**  
   Workflow starts on a **GitHub-hosted runner**. Runner has **no AWS credentials** by default.

2. **Request OIDC Token**  
   Runner requests a **token** from GitHub. Token contains claims such as:  
   - `aud`: `sts.amazonaws.com`  
   - `sub`: repository and branch information

3. **Assume IAM Role**  
   Runner calls `sts:AssumeRoleWithWebIdentity` using the OIDC token. Example IAM role trust policy:

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
      "token.actions.githubusercontent.com:sub": "repo:username/repo:ref:refs/heads/main"
    }
  }
}
````

4. **Temporary AWS Credentials**
   AWS returns **temporary credentials** (Access Key, Secret, Session Token). Credentials are valid **for a short period**.

5. **Access AWS Resources**
   Runner can now access AWS resources within the permissions of the IAM role. Permissions are **limited**.

---

## Key Points

| Feature                 | GitHub-Hosted Runner               |
| ----------------------- | ---------------------------------- |
| Runner location         | GitHub cloud (ephemeral)           |
| AWS credentials         | None by default                    |
| Auth method             | OIDC token                         |
| IAM Role trust          | GitHub OIDC provider               |
| Temporary credentials   | Issued by AWS STS                  |
| Lifetime of credentials | Short-lived                        |
| Typical use case        | CI/CD pipelines, ephemeral runners |

---

## Verification

Example GitHub Actions workflow step:

```yaml
steps:
  - name: Configure AWS Credentials via OIDC
    uses: aws-actions/configure-aws-credentials@v2
    with:
      role-to-assume: arn:aws:iam::<account-id>:role/github-oidc-role
      aws-region: us-east-1

  - name: Verify AWS Identity
    run: aws sts get-caller-identity
```

Expected output:

```json
{
    "Arn": "arn:aws:iam::<account-id>:role/github-oidc-role",
    "UserId": "...",
    "Account": "<account-id>"
}
```

---

| Feature             | GitHub-Hosted Runner                                                 | Self-Hosted Runner                                    |
| ------------------- | -------------------------------------------------------------------- | ----------------------------------------------------- |
| Location            | GitHub cloud (ephemeral)                                             | Your own VM or EC2                                    |
| IAM Authentication  | OIDC token → assume role                                             | Needs instance IAM role or AWS credentials configured |
| kubeconfig          | Configured in workflow using `aws-actions/configure-aws-credentials` | You must provide access manually                      |
| Default Permissions | Temporary, scoped to workflow                                        | Depends on IAM role/permissions on the host machine   |
