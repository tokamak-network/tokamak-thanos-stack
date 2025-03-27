terraform {
  required_version = ">= 1.0.0"

  backend "s3" {
    key            = "tokamak-thanos-stack/terraform/thanos-stack/terraform.tfstate"
    encrypt        = true
    dynamodb_table = "terraform-lock"
    timeouts {
      delete = "30m"
    } 
  }
}
