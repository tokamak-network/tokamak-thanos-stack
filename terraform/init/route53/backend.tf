terraform {
  required_version = ">= 1.0.0"

  backend "s3" {
    key            = "tokamak-thanos-stack/terraform/init/route53/terraform.tfstate"
    encrypt        = true
    dynamodb_table = "terraform-lock"
  }
}
