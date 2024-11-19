output "name_servers" {
  description = "Domain name servers"
  value       = aws_route53_zone.main.name_servers
}
