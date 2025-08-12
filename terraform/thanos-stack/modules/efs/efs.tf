data "aws_subnet" "private_subnets" {
  count = length(var.private_subnet_ids)

  id = var.private_subnet_ids[count.index]
}

data "aws_vpc" "vpc" {
  id = var.vpc_id
}

module "efs" {
  source = "terraform-aws-modules/efs/aws"
  version = "< 2.0.0"

  # File system
  name           = var.efs_name
  creation_token = "${var.efs_name}-token"
  encrypted      = true
  attach_policy  = false

  throughput_mode = "elastic"

  lifecycle_policy = {
    transition_to_ia = "AFTER_30_DAYS"
  }

  # Backup policy
  enable_backup_policy = true
}

# Optional AWS Backup resources
resource "aws_backup_vault" "this" {
  count = var.backup_enabled && var.backup_vault_name != "" ? 1 : 0

  name = var.backup_vault_name
}

resource "aws_backup_plan" "this" {
  count = var.backup_enabled ? 1 : 0

  name = "${var.efs_name}-backup-plan"

  rule {
    rule_name         = "${var.efs_name}-daily"
    target_vault_name = var.backup_vault_name != "" ? var.backup_vault_name : "Default"
    schedule          = var.backup_schedule_cron

    lifecycle {
      delete_after = var.backup_delete_after_days
    }
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "aws_backup_selection" "this" {
  count = var.backup_enabled ? 1 : 0

  iam_role_arn = var.backup_iam_role_arn != "" ? var.backup_iam_role_arn : "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/service-role/AWSBackupDefaultServiceRole"
  name         = "${var.efs_name}-selection"
  plan_id      = aws_backup_plan.this[0].id

  # Use resources when no tags are specified, otherwise use selection tags
  resources = length(var.backup_resource_tags) == 0 ? [
    "arn:aws:elasticfilesystem:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:file-system/${module.efs.id}"
  ] : []

  dynamic "selection_tag" {
    for_each = var.backup_resource_tags
    content {
      type  = "STRINGEQUALS"
      key   = selection_tag.key
      value = selection_tag.value
    }
  }

  depends_on = [module.efs, aws_backup_plan.this]
}

resource "aws_security_group" "this" {
  name        = var.efs_name
  description = "EFS security group"

  revoke_rules_on_delete = true
  vpc_id                 = var.vpc_id
}

resource "aws_security_group_rule" "this" {
  security_group_id = aws_security_group.this.id

  description = "NFS ingress from VPC private subnets"
  type        = "ingress"
  from_port   = "2049"
  to_port     = "2049"
  protocol    = "tcp"
  cidr_blocks = [data.aws_vpc.vpc.cidr_block]
}

resource "aws_efs_mount_target" "this" {
  count = length(data.aws_subnet.private_subnets)

  file_system_id  = module.efs.id
  security_groups = [aws_security_group.this.id]
  subnet_id       = data.aws_subnet.private_subnets[count.index].id
}
