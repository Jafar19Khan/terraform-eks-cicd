terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "devops-project-19"
      Component   = "jenkins-server"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}
