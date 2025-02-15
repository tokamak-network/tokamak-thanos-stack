resource "aws_secretsmanager_secret" "sequencer_keys" {
  name                    = "${var.secretsmanager_name}/secrets"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "sequencer_keys" {
  secret_id = aws_secretsmanager_secret.sequencer_keys.id

  secret_string = jsonencode({
    OP_NODE_P2P_SEQUENCER_KEY = var.sequencer_key
    OP_BATCHER_PRIVATE_KEY    = var.batcher_key
    OP_PROPOSER_PRIVATE_KEY   = var.proposer_key
    OP_CHALLENGER_PRIVATE_KEY = var.challenger_key
  })
}
