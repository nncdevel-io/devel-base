# バックアップ専用 S3 バケットとライフサイクル。
# TASK-025 の backup-all.sh が出力するアーカイブ（GitLab・Jenkins・
# Redmine・共有 PostgreSQL）をここに保管する。
#
# 命名は要件書 9.1 に従い devel-base-backup-<account-id>。
# 30 日経過分を自動削除（TASK-007 補足）。

terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

data "aws_caller_identity" "current" {}

locals {
  bucket_name = coalesce(
    var.bucket_name,
    "${var.project}-backup-${data.aws_caller_identity.current.account_id}",
  )
}

resource "aws_s3_bucket" "this" {
  bucket = local.bucket_name

  tags = merge(
    var.tags,
    {
      Name    = local.bucket_name
      Purpose = "devel-base-backup"
    },
  )
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# 現行版は保持期限経過で expire、旧版は短めに gc、未完了マルチパートも掃除
resource "aws_s3_bucket_lifecycle_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    id     = "expire-current-backups"
    status = "Enabled"

    filter {}

    expiration {
      days = var.retention_days
    }

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_retention_days
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  depends_on = [aws_s3_bucket_versioning.this]
}
