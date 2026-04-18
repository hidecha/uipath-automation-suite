terraform {
  required_providers {
    postgresql = {
      source  = "cyrilgdn/postgresql"
      version = "~> 1.25"
    }
  }
}

# Automation Suite on EKS
provider "aws" {
  region = var.region
  default_tags {
    tags = var.tags
  }
}

provider "postgresql" {
  host     = aws_db_instance.postgres_instance.address
  port     = var.postgres_port
  username = var.postgres_username
  password = var.postgres_password
  sslmode  = "require"
}

data "aws_caller_identity" "current" {}
