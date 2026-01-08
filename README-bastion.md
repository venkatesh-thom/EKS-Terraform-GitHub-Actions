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

------------------------------------------------------------------------

## 🎯 Interview Points (DevOps / DevSecOps)

You can say:

> We use AWS SSM Session Manager instead of SSH bastions. This avoids
> key management, removes inbound access, and provides full audit logs
> through CloudTrail.

------------------------------------------------------------------------


