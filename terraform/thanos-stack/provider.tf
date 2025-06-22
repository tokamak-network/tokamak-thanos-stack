terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.17.0, < 6.0.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}
