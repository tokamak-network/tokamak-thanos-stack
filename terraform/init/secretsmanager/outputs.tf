output "aws_secretsmanager_id" {
  value = aws_secretsmanager_secret.sequencer_keys.id
}
