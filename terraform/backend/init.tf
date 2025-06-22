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

resource "random_string" "randomname" {
  length  = 8
  special = false
  upper   = false
}

resource "aws_s3_bucket" "tfstate" {
  bucket = "${var.thanos_stack_name}-thanos-stack-tfstate-${random_string.randomname.result}"

  versioning {
    enabled = true # Prevent from deleting tfstate file
  }

  lifecycle {
    prevent_destroy = false
  }

  force_destroy = true
}

# DynamoDB for terraform state lock
resource "aws_dynamodb_table" "terraform_state_lock" {
  name         = "${var.thanos_stack_name}-terraform-lock"
  hash_key     = "LockID"
  billing_mode = "PAY_PER_REQUEST"

  attribute {
    name = "LockID"
    type = "S"
  }
}


resource "terraform_data" "env_bucket_name" {
  provisioner "local-exec" {
    command = "./bucket_name.sh"

    environment = {
      NEW_BUCKET_NAME = "${var.thanos_stack_name}-thanos-stack-tfstate-${random_string.randomname.result}"
    }
  }
}
