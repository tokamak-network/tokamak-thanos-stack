resource "aws_route53_zone" "main" {
  name          = var.chain_domain_name
  force_destroy = true
}
