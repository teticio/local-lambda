terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

provider "aws" {
  profile = var.profile
  region  = var.region

  default_tags {
    tags = {
      Name          = "EC2"
      ManagedBy     = "Terraform"
      ManagedByType = "IAC"
    }
  }
}
