output "bucket_name" {
  description = "作成したバックアップ用 S3 バケットの名前"
  value       = aws_s3_bucket.this.bucket
}

output "bucket_arn" {
  description = "作成したバックアップ用 S3 バケットの ARN。EC2 IAM Role の s3 権限スコープに使用"
  value       = aws_s3_bucket.this.arn
}
