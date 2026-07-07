# 🚀 Configuring Production-Ready EKS AutoClusters with Terraform and GitHub Actions


![EKS- GitHub Actions- Terraform](assets/Presentation1.gif)


## 🌟 Overview

This project covers:
- **Infrastructure as Code (IaC)**: Use Terraform to define and manage your EKS cluster.
- **CI/CD Automation**: Leverage GitHub Actions to automate deployments.
# GitHub-Hosted Runner with AWS OIDC Flow

---

This document explains the authentication flow for **GitHub-hosted runners** accessing AWS resources via **OIDC (OpenID Connect)**.


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


---
# 🛡️ Bastion Host Setup on AWS (SSH + SSM) --- Step-by-Step

This guide explains how to access EC2 instances using a **Bastion Host**
in two ways:

1.  🔐 SSH using Key Pair\
2.  ✅ AWS SSM Session Manager (No SSH, No Key --- Recommended)

It also includes **Terraform examples** and **verification steps**.

------------------------------------------------------------------------

## 🧱 Architecture

    Your Laptop
        |
        | (SSH / SSM)
        v
    [Bastion Host - Public Subnet]
        |
        | (SSH or SSM)
        v
    [Private EC2 - Private Subnet]

------------------------------------------------------------------------

## ✅ Option 1: Bastion Using SSH (Classic Way)

### 1. Create Key Pair

AWS Console: - EC2 → Key Pairs → Create key pair - Name: bastion-key -
Download `bastion-key.pem`

On your laptop:

``` bash
chmod 400 bastion-key.pem
```

------------------------------------------------------------------------

### 2. Bastion Security Group (Terraform)

Allow SSH only from your public IP:

``` hcl
resource "aws_security_group" "bastion_sg" {
  name   = "bastion-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["YOUR_PUBLIC_IP/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

------------------------------------------------------------------------

### 3. Bastion EC2 (Terraform)

``` hcl
resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids       = [aws_security_group.bastion_sg.id]
  associate_public_ip_address = true
  key_name                    = "bastion-key"

  tags = {
    Name = "bastion"
  }
}
```

------------------------------------------------------------------------

### 4. Connect to Bastion

``` bash
ssh -i bastion-key.pem ec2-user@<BASTION_PUBLIC_IP>
```

Ubuntu AMI:

``` bash
ssh -i bastion-key.pem ubuntu@<BASTION_PUBLIC_IP>
```

------------------------------------------------------------------------

### 5. Private EC2 Security Group

Allow SSH only from Bastion SG:

``` hcl
ingress {
  from_port       = 22
  to_port         = 22
  protocol        = "tcp"
  security_groups = [aws_security_group.bastion_sg.id]
}
```

------------------------------------------------------------------------

### 6. Bastion → Private EC2

From bastion terminal:

``` bash
ssh ec2-user@<PRIVATE_IP>
```

(If key is needed, copy key carefully --- not recommended in production)

------------------------------------------------------------------------

## ✅ Option 2: Bastion Using AWS SSM (NO SSH, NO KEY) ✅ BEST PRACTICE

### ✔ Benefits

-   No inbound rules
-   No key pairs
-   IAM controlled
-   Logged in CloudTrail

------------------------------------------------------------------------

### 1. IAM Role for EC2 (Terraform)

``` hcl
resource "aws_iam_role" "ec2_ssm_role" {
  name = "ec2-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_attach" {
  role       = aws_iam_role.ec2_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2-ssm-profile"
  role = aws_iam_role.ec2_ssm_role.name
}
```

------------------------------------------------------------------------

### 2. Attach Role to Bastion EC2

``` hcl
resource "aws_instance" "bastion" {
  ...
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name
}
```

------------------------------------------------------------------------

### 3. Bastion Security Group (SSM)

Only egress needed:

``` hcl
egress {
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]
}
```

No ingress required ✅

------------------------------------------------------------------------

### 4. Connect Using Console

EC2 → Instances → Select Bastion → Connect → Session Manager → Connect

------------------------------------------------------------------------

### 5. Connect Using AWS CLI

``` bash
aws ssm start-session --target i-xxxxxxxxxxxxx
```

------------------------------------------------------------------------

## 🔐 Private EC2 with SSM (No Bastion Needed)

You can attach same IAM role to private EC2 and connect directly:

-   No public IP
-   No bastion required
-   Works via SSM

Security team preferred architecture.

------------------------------------------------------------------------

## 🧪 Troubleshooting

### ❌ SSH Not Working

Check: - Public IP exists - Port 22 open in SG - Correct username - Key
pair exists

------------------------------------------------------------------------

### ❌ Session Manager Not Working

Check: - IAM role attached - Policy: AmazonSSMManagedInstanceCore -
Instance has internet or VPC endpoints - SSM agent running

``` bash
sudo systemctl status amazon-ssm-agent
```

---

