resource "random_string" "randomname" {
  length  = 8
  special = false
  upper   = false
}

resource "aws_s3_bucket" "config_files" {
  bucket = "${var.thanos_stack_name}-config-${random_string.randomname.result}"
}

resource "aws_s3_bucket_public_access_block" "public_access" {
  bucket = aws_s3_bucket.config_files.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_object" "provision_genesis_file" {
  bucket = aws_s3_bucket.config_files.id
  key    = "thanos-stack/genesis.json"
  source = var.genesis_file_path
}

resource "aws_s3_object" "provision_rollup_file" {
  bucket = aws_s3_bucket.config_files.id
  key    = "thanos-stack/rollup.json"
  source = var.rollup_file_path
}

resource "aws_s3_object" "provision_prestate_file" {
  bucket = aws_s3_bucket.config_files.id
  key    = "thanos-stack/${var.prestate_hash}.json"
  source = var.prestate_file_path
}

resource "aws_s3_bucket_policy" "bucket_policy" {
  bucket = aws_s3_bucket.config_files.id

  depends_on = [
    aws_s3_bucket_public_access_block.public_access
  ]

  policy = <<POLICY
{
  "Version":"2012-10-17",
  "Statement":[
    {
      "Sid":"PublicRead",
      "Effect":"Allow",
      "Principal": "*",
      "Action":["s3:GetObject"],
      "Resource":["arn:aws:s3:::${aws_s3_bucket.config_files.id}/*"]
    }
  ]
}
POLICY
}
