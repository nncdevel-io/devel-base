#!/usr/bin/env bash
# Terraform バックエンド用の S3 バケットと DynamoDB テーブルを構築する。
# 要件書 9.2、TASK-003 の成果物。
#
# 本スクリプトは Terraform 管理外の前提（terraform init より前に
# 一度だけ実行する）。冪等に動作するため再実行しても安全。
#
# 前提:
#   - AWS CLI v2 がインストール済で、認証情報が設定済
#     （AssumeRole 後の一時クレデンシャルでも可）
#   - 対象 AWS アカウントで s3:* と dynamodb:* の権限を持つこと
#
# 使い方:
#   ./scripts/bootstrap-tf-backend.sh
#   AWS_REGION=ap-northeast-1 PROJECT=devel-base ./scripts/bootstrap-tf-backend.sh

set -euo pipefail

REGION="${AWS_REGION:-ap-northeast-1}"
PROJECT="${PROJECT:-devel-base}"

ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
BUCKET="${PROJECT}-tfstate-${ACCOUNT_ID}"
TABLE="${PROJECT}-tfstate-lock"

echo "[bootstrap] account=${ACCOUNT_ID} region=${REGION}"
echo "[bootstrap] bucket=${BUCKET} table=${TABLE}"

# ---- S3 バケット ----
if aws s3api head-bucket --bucket "${BUCKET}" --region "${REGION}" 2>/dev/null; then
  echo "[s3] ${BUCKET} はすでに存在します。設定のみ確認します"
else
  echo "[s3] ${BUCKET} を新規作成します"
  aws s3api create-bucket \
    --bucket "${BUCKET}" \
    --region "${REGION}" \
    --create-bucket-configuration "LocationConstraint=${REGION}" \
    >/dev/null
fi

# バージョニング有効化（tfstate の世代管理）
aws s3api put-bucket-versioning \
  --bucket "${BUCKET}" \
  --versioning-configuration Status=Enabled

# パブリックアクセス完全ブロック
aws s3api put-public-access-block \
  --bucket "${BUCKET}" \
  --public-access-block-configuration \
  "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

# デフォルト暗号化（AES256）
aws s3api put-bucket-encryption \
  --bucket "${BUCKET}" \
  --server-side-encryption-configuration '{
    "Rules": [
      {
        "ApplyServerSideEncryptionByDefault": { "SSEAlgorithm": "AES256" },
        "BucketKeyEnabled": true
      }
    ]
  }'

# tfstate の旧バージョンを 90 日で完全削除（誤上書き時の復旧猶予を確保）
aws s3api put-bucket-lifecycle-configuration \
  --bucket "${BUCKET}" \
  --lifecycle-configuration '{
    "Rules": [
      {
        "ID": "expire-noncurrent-tfstate",
        "Status": "Enabled",
        "Filter": {},
        "NoncurrentVersionExpiration": { "NoncurrentDays": 90 },
        "AbortIncompleteMultipartUpload": { "DaysAfterInitiation": 7 }
      }
    ]
  }'

echo "[s3] ${BUCKET} の設定完了"

# ---- DynamoDB テーブル ----
if aws dynamodb describe-table --table-name "${TABLE}" --region "${REGION}" >/dev/null 2>&1; then
  echo "[dynamodb] ${TABLE} はすでに存在します"
else
  echo "[dynamodb] ${TABLE} を新規作成します"
  aws dynamodb create-table \
    --table-name "${TABLE}" \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region "${REGION}" \
    >/dev/null
  aws dynamodb wait table-exists --table-name "${TABLE}" --region "${REGION}"
fi

# 誤削除防止
aws dynamodb update-table \
  --table-name "${TABLE}" \
  --region "${REGION}" \
  --deletion-protection-enabled \
  >/dev/null 2>&1 || true

echo "[dynamodb] ${TABLE} の設定完了"

cat <<EOF

Terraform バックエンドの構築が完了しました。
terraform/envs/dev/main.tf に以下を追加してください:

terraform {
  backend "s3" {
    bucket         = "${BUCKET}"
    key            = "envs/dev/terraform.tfstate"
    region         = "${REGION}"
    dynamodb_table = "${TABLE}"
    encrypt        = true
  }
}
EOF
