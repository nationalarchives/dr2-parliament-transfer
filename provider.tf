terraform {
  required_version = ">= 1.7.0, < 2.0.0"

  backend "s3" {
    bucket       = "pa-transfer-terraform-state-bucket"
    key          = "terraform.state"
    region       = "eu-west-2"
    encrypt      = true
    use_lockfile = true
  }

  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
}
