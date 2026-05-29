# devel-base

開発に必要なツール群（GitLab・Jenkins・Redmine・SonarQube）を 1 台の
EC2 上に集約した、小規模チーム向けの開発基盤です。

## 構成

- ホスト: AWS EC2 t3.xlarge 1 台、Amazon Linux 2023
- ランタイム: Docker Compose v2
- リバプロ: Caddy（証明書は外部リポジトリで管理、S3 経由で配布）
- サービス: GitLab CE / Jenkins LTS / Redmine / SonarQube Community
- 共有 DB: PostgreSQL 18（Redmine / SonarQube 用）
- 認証: GitLab を Identity Bridge として他 3 サービスへ OAuth 委譲

詳細は [docs/requirements.md](docs/requirements.md) を参照。

## 利用イメージ

3 つのフェーズで段階的に立ち上げます。

### Phase 1: AWS リソース構築（Terraform）

ローカル PC から AWS API へ HTTPS 経由で Terraform を実行します。
EC2 にログインする必要はありません。

```bash
# AWS 認証（SSO / アクセスキー / プロファイル）
aws sso login --profile devel-base

# tfstate 用 backend を作成（1 回だけ、冪等）
./scripts/bootstrap-tf-backend.sh

# インフラ構築
cd terraform/envs/dev
terraform init
terraform apply
```

作成されるもの:

- VPC / Subnet / Security Group / Route53
- EC2 t3.xlarge + EIP + EBS
- IAM Role（EC2 が S3 から config を read する権限）
- S3 バケット（config 配布 + バックアップ兼用）
- EventBridge Scheduler（平日 8:00-22:00 JST 起動停止）

### Phase 2: アプリケーション配備

リポジトリ内のコードを S3 にアップロードすれば、EC2 が自動で
取得して起動します。

```bash
# ローカルからコードを S3 に同期
aws s3 sync compose/ s3://devel-base-backup-<account-id>/config/compose/
aws s3 sync scripts/ s3://devel-base-backup-<account-id>/config/scripts/
```

EC2 側では user_data が初回 boot で次を自動実行します。

1. S3（`config/` プレフィックス）から `/opt/devel-base/` に sync
2. `compose/.env` が存在しなければ openssl で秘密値を生成
3. 別リポジトリで管理される最新の TLS 証明書を S3 から
   `/opt/devel-base/certs/` に取得
4. systemd unit（`devel-base.service` および証明書更新 timer）を有効化
5. `docker compose up -d` でコンテナ起動

完了後、4 サービスが利用可能になります。

- <https://gitlab.devel-base.example.com>
- <https://jenkins.devel-base.example.com>
- <https://redmine.devel-base.example.com>
- <https://sonarqube.devel-base.example.com>

### Phase 3: 初期設定（ブラウザで手動）

初回のみ必要な手動操作です。

- GitLab root パスワードの設定
- GitLab で OAuth Application 登録（Jenkins / Redmine / SonarQube 用）
- 各サービス側で OAuth 連携の設定
- Jenkins / Redmine / SonarQube の管理者ユーザ作成

詳細手順は `docs/runbook/03-initial-config.md`（作成予定）に記載します。

## TLS 証明書

HTTPS 証明書の取得と自動更新は **本リポジトリの管理対象外** です。
別リポジトリで運用される `acme-cert-updater`（AWS Lambda + Let's Encrypt +
Route 53 DNS-01）が、約 60 日サイクルで証明書を S3 に配置します。
devel-base はその S3 上の証明書を消費する側のみを担当します。

```text
[別リポジトリ管理]
  acme-cert-updater が Let's Encrypt から取得して S3 に保存
        │
        ▼
[S3: <bucket>/<prefix>/<timestamp>/{fullchain,privkey}.pem]
        │
        │ EC2 の systemd timer が日次で latest を取得
        ▼
[EC2: /opt/devel-base/certs/] → Caddy が TLS 終端
```

主な取り決め:

- 証明書本体は EC2 ローカル（`/opt/devel-base/certs/`）にのみ存在し、
  EBS の保管時暗号化で保護される（KMS / Secrets Manager 不要）
- S3 バケット名と prefix は Terraform 変数で外出しする
  （将来 DNS / 証明書管理を別 AWS アカウントへ移す場合に備える）
- 初回 boot は user_data が同期し、以後は systemd timer が日次で
  最新版を取得して差分があれば Caddy をリロードする
- 通常運用で運用者が証明書ファイルに触れる場面はない

## 平時の運用

### コンテナのアップデート

イメージタグ変更後、SSM Session で EC2 に接続して反映します。

```bash
# ローカル: コード変更を S3 へ
git pull
aws s3 sync compose/ s3://devel-base-backup-<account-id>/config/compose/

# EC2（SSM Session 経由で接続）
cd /opt/devel-base
aws s3 sync s3://devel-base-backup-<account-id>/config/ .
docker compose -f compose/docker-compose.yml pull
docker compose -f compose/docker-compose.yml up -d
./scripts/healthcheck.sh
```

### バックアップと復旧

デイリーで自動取得します（要件書 5.4）。

- EBS スナップショット（OS / volume 全体）
- pg_dumpall（Redmine / SonarQube DB）
- Redmine files（添付ファイル）

ロールバック手順は要件書 6.5 を参照してください。

## ドキュメント

- 要件: [docs/requirements.md](docs/requirements.md)
- タスク一覧: [docs/task.md](docs/task.md)
- 要検証事項: [docs/verification-ledger.md](docs/verification-ledger.md)
- 運用 Runbook: `docs/runbook/`（作成予定）

## ライセンス

社内利用限定。
