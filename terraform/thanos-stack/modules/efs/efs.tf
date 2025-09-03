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

  # Backup policy - Always disable EFS built-in backup, use AWS Backup service instead
  enable_backup_policy = false
}

# Custom AWS Backup resources - Always enabled for production-ready backup protection

# Create IAM role for AWS Backup
resource "aws_iam_role" "backup_service_role" {
  name = "${var.efs_name}-backup-service-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "backup.amazonaws.com"
        }
      }
    ]
  })
}

# Attach AWS managed policy for backup service role
resource "aws_iam_role_policy_attachment" "backup_service_role_policy" {
  role       = aws_iam_role.backup_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

# Attach AWS managed policy for restore service role
resource "aws_iam_role_policy_attachment" "backup_service_role_restore_policy" {
  role       = aws_iam_role.backup_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForRestores"
}

# Create backup vault with stack name
resource "aws_backup_vault" "this" {
  name = "${var.efs_name}-backup-vault"
}

# Create backup plan
resource "aws_backup_plan" "this" {
  name = "${var.efs_name}-backup-plan"

  rule {
    rule_name         = "${var.efs_name}-daily"
    target_vault_name = aws_backup_vault.this.name
    schedule          = var.backup_schedule_cron

    # Only set lifecycle if retention is not unlimited (0)
    dynamic "lifecycle" {
      for_each = var.backup_delete_after_days > 0 ? [1] : []
      content {
        delete_after = var.backup_delete_after_days
      }
    }
  }

  depends_on = [aws_backup_vault.this]
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Create backup selection to include this EFS
resource "aws_backup_selection" "this" {
  iam_role_arn = aws_iam_role.backup_service_role.arn
  name         = "${var.efs_name}-selection"
  plan_id      = aws_backup_plan.this.id

  # Always include this EFS in backup selection
  resources = [
    "arn:aws:elasticfilesystem:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:file-system/${module.efs.id}"
  ]

  depends_on = [module.efs, aws_backup_plan.this, aws_iam_role.backup_service_role]
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
