variable "project" {
  description = "リソース命名のプレフィックス（要件書 9.1 のハイフン表記）"
  type        = string
  default     = "devel-base"
}

variable "bucket_name" {
  description = "S3 バケット名を明示指定する場合に使用。未指定なら <project>-backup-<account-id> で自動命名"
  type        = string
  default     = null
}

variable "retention_days" {
  description = "現行版バックアップオブジェクトの保持日数。TASK-007 補足にしたがい 30 日"
  type        = number
  default     = 30
}

variable "noncurrent_retention_days" {
  description = "バージョニング上の旧オブジェクトの保持日数。誤上書きからの復旧猶予を確保しつつコストを抑える"
  type        = number
  default     = 7
}

variable "tags" {
  description = "S3 バケットに付与する共通タグ"
  type        = map(string)
  default     = {}
}
