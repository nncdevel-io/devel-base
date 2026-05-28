# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code)
when working with code in this repository.

## このリポジトリの位置付け

GitLab・Jenkins・Redmine・SonarQube を AWS の EC2 1 台上に
Docker Compose で同居運用する「devel-base」を構築する IaC
リポジトリ。社内利用者数名規模・コスト最小化を最優先とした構成。

現状は M1 マイルストーン進行中で、ディレクトリ構造と
ドキュメントのみが存在する初期状態。実コード（Terraform、
docker-compose.yml、スクリプト類）はこれから実装する段階。

## 設計の単一情報源

実装判断・レビュー・新規タスク追加の前に必ず以下を参照する。
要件書とタスク表が乖離した場合は要件書を正とし、タスク側を
更新する。

- `docs/requirements.md`: 全要件（アーキテクチャ、コンテナ構成、
  バージョンアップ戦略、認証連携、AWS リソース、IaC 方針、
  リスク）の唯一の出典
- `docs/task.md`: M1 のタスク一覧と DependsOn 依存関係
- `docs/verification-ledger.md`: 要検証事項台帳（社内 IP CIDR、
  VPC CIDR、Entra ID 連携など、構築前に確定が必要な値）

## タスク運用ルール（docs/task.md より）

- タスク着手時にステータスを `⏳` → `🚧` に更新する
- 完了時に `🚧` → `✅` に更新する
- `DependsOn` のタスクがすべて `✅` でない限り着手しない
- ステータス記号: `⏳` 未着手 / `🚧` 作業中 / `🧪` 確認待ち /
  `✅` 完了 / `🚫` 中止

タスクを進める場合は対応する `TASK-XXX` を確認し、補足・注意欄に
書かれた要件書参照節（例: 「要件書 3.6 にしたがって」）に必ず
従う。

## アーキテクチャ要点（実装時の判断基準）

詳細は要件書を参照。コードを書く際に常に効いてくる原則のみ
ここに記す。

- **イメージタグは latest 禁止**。メジャー.マイナーで固定する
  （要件書 6.1、6.2）。Renovate Bot 連携を前提とする
- **データは Docker named volume に分離**。コンテナ再作成で
  消えてはならない（GitLab config/data/logs、JENKINS_HOME、
  Redmine files/plugins/config、各 DB data、Caddy 証明書）
- **HTTPS 終端は Caddy + Let's Encrypt**。ALB・ACM は使わない
- **認証は GitLab を Identity Bridge** とする。Entra ID →
  GitLab → 他 3 サービスへ OAuth 委譲（要件書 7 章）
- **EC2 1 台構成**: t3.xlarge、Single-AZ、平日 8:00-22:00 JST
  稼働。SSH は開放せず Session Manager 経由。IMDSv2 強制
- **Security Group Inbound は 443/80 のみ、社内 IP CIDR 限定**
  （`docs/verification-ledger.md` V-03 詳細表の 5 CIDR）
- **Redmine は公式イメージを Dockerfile で拡張**。プラグインの
  `bundle install` と `redmine:plugins:migrate` を起動時に
  自動実行する（要件書 4.3、6.8）
- **DB マイグレーション後のロールバックはタグ巻き戻し不可**。
  バックアップからの DB 復元を前提に手順化する（要件書 6.5）

## 命名規約（要件書 9.1）

ハイフン表記とアンダースコア表記を用途で使い分ける。混在禁止。

- `devel-base`（ハイフン）: リポジトリ名・FQDN・Name タグ・
  S3 バケット名・コンテナ名など外部に露出する識別子
- `devel_base`（アンダースコア）: Terraform 識別子・シェル変数
  など HCL がハイフンを許さない箇所

FQDN は `<service>.devel-base.example.com` 形式
（gitlab/jenkins/redmine/sonarqube の 4 サブドメイン）。

## ディレクトリ構成（要件書 9.3 が正）

```text
terraform/
  envs/dev/                # エントリーポイント (main.tf, variables.tf, tfvars)
  modules/
    network/               # VPC, Subnet, IGW, VPC Endpoint
    security/              # SG, IAM Role
    route53/               # Hosted Zone, A レコード
    backup/                # S3 バケット, ライフサイクル
    ec2_host/              # EC2, EIP, EBS, user_data
    scheduler/             # EventBridge Scheduler 起動停止
compose/
  docker-compose.yml       # 4 サービス + Caddy
  Caddyfile                # 4 ドメインのリバプロ
  .env.example             # 機密値はテンプレートのみ
  redmine/Dockerfile       # 公式イメージ拡張
  redmine/plugin-migrate-and-start.sh
scripts/
  backup-all.sh
  restore.sh
  healthcheck.sh
docs/
  requirements.md
  task.md
  verification-ledger.md
```

実体ファイル未作成のディレクトリは `.gitkeep` で保持されている。
モジュールやスクリプトを追加するときはこの構成に従う。

## 機密情報の扱い

`.gitignore` で以下を除外済。これらを誤って Git に載せない。

- `*.tfvars` / `*.tfvars.json`（`terraform.tfvars.example` のみ例外）
- `compose/.env` / `compose/*.env`（`.env.example` のみ例外）
- `*.tfstate*`、`*.tfplan`、`override.tf`

OAuth Client Secret などの実値は SSM Parameter Store
（SecureString）または Secrets Manager 経由で注入する想定
（要件書 9.4）。コード・ドキュメントへの直書き禁止。

## 検証コマンド

### Markdown

`.markdownlint-cli2.jsonc` で MD013（line-length: tables/code
を除外）と MD024（重複見出し許可）を緩和済。`.md` を編集・追加
したら必ず実行する。

```bash
markdownlint-cli2 "**/*.md"
markdownlint-cli2-fix "**/*.md"   # 自動修正
```

### Terraform（実装着手後）

各モジュール・envs 配下で `init/fmt/validate/plan` を実行する。
S3 + DynamoDB バックエンドは Terraform 管理外で先行構築する
（TASK-003）。

```bash
terraform -chdir=terraform/envs/dev init
terraform -chdir=terraform/envs/dev fmt -recursive
terraform -chdir=terraform/envs/dev validate
terraform -chdir=terraform/envs/dev plan
```

### Docker Compose（実装着手後）

```bash
docker compose -f compose/docker-compose.yml config       # 構文検証
docker compose -f compose/docker-compose.yml pull
docker compose -f compose/docker-compose.yml up -d
./scripts/healthcheck.sh                                  # 4 サービス疎通確認
```

## ドキュメント言語

このリポジトリの既存ドキュメント（README、要件書、タスク表、
台帳）はすべて日本語。新規・追記ともに日本語で書く。Terraform の
description やコードコメントも、ユーザ向け文言は日本語を基本と
する。
