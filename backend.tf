terraform {
  required_version = "~> 1.9.3"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.49.0"
    }

    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.10.0"
    }

  }

  backend "s3" {
    bucket         = "venkatesh-01a73d48"
    key            = "eks-vpc/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "Lock-Files"
    encrypt        = true
  }
}


provider "aws" {
  region = var.aws-region
}
