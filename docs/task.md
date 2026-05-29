# TASKS

マイルストーン: M1 devel-base 本番運用開始
ゴール: AWS 上に GitLab・Jenkins・Redmine・SonarQube の統合開発環境を IaC で構築し、社内利用可能な状態にする

## ワークフロールール

- タスク着手時にステータスを 🚧 に更新する
- タスク完了時にステータスを ✅ に更新する
- DependsOn のタスクがすべて ✅ でないタスクには着手しない

## ステータス表記ルール

| Status | 意味 |
| ---- | ----- |
| ⏳ | 未着手、TODO |
| 🚧 | 作業中、IN_PROGRESS |
| 🧪 | 確認待ち、REVIEW |
| ✅ | 完了、DONE |
| 🚫 | 中止、CANCELLED |

## タスク一覧

| ID | Status | Summary | DependsOn |
| --- | --- | --- | --- |
| TASK-001 | ✅ | 要検証事項を洗い出し前提条件を確定する | - |
| TASK-002 | ✅ | リポジトリのディレクトリ構成とベースファイルを作成する | - |
| TASK-013 | ✅ | Caddyfile（4 ドメインのリバプロ設定）を作成する | TASK-002 |
| TASK-014 | ✅ | docker-compose.yml（4 サービス + Caddy）を作成する | TASK-002 |
| TASK-015 | ✅ | .env.example（環境変数テンプレート）を作成する | TASK-014 |
| TASK-016 | ✅ | Redmine カスタム Dockerfile を作成する | TASK-002 |
| TASK-017 | ✅ | プラグイン bundle install と db migrate の起動スクリプトを作成する | TASK-016 |
| TASK-018 | 🧪 | Docker Compose で初回起動し 4 サービスの疎通を確認する | TASK-013,TASK-014,TASK-015,TASK-017 |
| TASK-024 | ⏳ | healthcheck.sh（4 サービスの稼働確認）を作成する | TASK-018 |
| TASK-025 | ⏳ | backup-all.sh（GitLab・Jenkins・Redmine の日次バックアップ）を作成する | TASK-018 |
| TASK-026 | ⏳ | restore.sh（バックアップからの復元手順）を作成する | TASK-025 |
| TASK-028 | ✅ | Renovate Bot でイメージタグ更新検知の MR 自動生成を設定する | TASK-014 |
| TASK-003 | 🧪 | Terraform バックエンド用の S3 と DynamoDB を構築する | TASK-001 |
| TASK-004 | ⏳ | network モジュール（VPC・Subnet・IGW・VPC Endpoint）を実装する | TASK-002,TASK-003 |
| TASK-005 | ⏳ | security モジュール（Security Group・IAM Role）を実装する | TASK-004 |
| TASK-006 | ✅ | route53 モジュール（Hosted Zone・A レコード）を実装する | TASK-002 |
| TASK-007 | ✅ | backup モジュール（S3 バケット・ライフサイクル）を実装する | TASK-002 |
| TASK-008 | ✅ | EC2 user_data スクリプト（Docker・OS チューニング）を作成する | TASK-002 |
| TASK-009 | ⏳ | ec2_host モジュール（EC2・EIP・EBS）を実装する | TASK-005,TASK-008 |
| TASK-010 | ⏳ | scheduler モジュール（EventBridge Scheduler 起動停止）を実装する | TASK-009 |
| TASK-011 | ⏳ | envs/dev エントリーポイント（main.tf・variables.tf・tfvars）を実装する | TASK-004,TASK-005,TASK-006,TASK-007,TASK-009,TASK-010 |
| TASK-012 | ⏳ | Terraform apply で AWS 基盤一式を構築する | TASK-011 |
| TASK-019 | ⏳ | GitLab と Entra ID の SAML/OIDC SSO を設定する | TASK-018 |
| TASK-020 | ⏳ | GitLab に OAuth Application を 3 件登録する | TASK-019 |
| TASK-021 | ⏳ | Jenkins に GitLab Authentication Plugin で OAuth 認証を設定する | TASK-020 |
| TASK-022 | ⏳ | Redmine に redmine_oauth プラグインで GitLab OAuth を設定する | TASK-020 |
| TASK-023 | ⏳ | SonarQube に GitLab OAuth 認証を設定する | TASK-020 |
| TASK-027 | ⏳ | バックアップ取得とリストアの動作検証を実施する | TASK-025,TASK-026 |
| TASK-029 | ⏳ | 構築手順書を作成する | TASK-012,TASK-018 |
| TASK-030 | ⏳ | 運用手順書（起動停止・バックアップ・復旧・更新）を作成する | TASK-021,TASK-022,TASK-023,TASK-024,TASK-026,TASK-027 |
| TASK-031 | ⏳ | ネットワーク構成図とコンテナ構成図を作成する | TASK-012,TASK-018 |
| TASK-032 | ✅ | IaC 検証ハーネス候補（conftest 等）を比較し採用ツールを選定する | - |
| TASK-033 | ⏳ | 採用ハーネスをリポジトリに組み込み既存成果物で通過させる | TASK-032 |

## タスク詳細

### TASK-001

- 補足: 要件書 11.1 節（Entra ID 登録権限、VPC CIDR、社内 NAT IP、SCP/Config、バージョン互換性）を確認し台帳化する
- 注意: 関係部門への確認待ちは別途トラッキングする

### TASK-003

- 補足: バックエンドは S3 + DynamoDB ロック。バックエンド自体は Terraform 管理外で構築する
- 注意: バックエンド用 S3 と TASK-007 のバックアップ用 S3 は別バケット
- 成果物（2026-05-29）: `scripts/bootstrap-tf-backend.sh` を作成。
  ap-northeast-1 で `devel-base-tfstate-<account-id>` バケット
  （バージョニング・パブリックアクセス遮断・AES256 暗号化・
  noncurrent 90 日 expire）と `devel-base-tfstate-lock` テーブル
  （PAY_PER_REQUEST・deletion-protection 有効）を冪等構築する
- 残作業: 対象 AWS アカウントの認証情報下で
  `./scripts/bootstrap-tf-backend.sh` を実行すること（運用作業）

### TASK-004

- 補足: VPC CIDR は `10.x.0.0/24`、パブリックサブネット 1 個のみ、S3 Gateway VPC Endpoint を含める

### TASK-005

- 補足: 443/80 は社内 IP CIDR のみ許可。許可対象は以下 5 件
  - `118.238.15.65/32`（汐留インターネットゲートウェイ）
  - `121.83.239.1/32`（中之島インターネットゲートウェイ）
  - `3.114.145.178/32`（gitlab.nncdevel.io）
  - `20.89.59.132/32`（VDI 環境）
  - `20.89.58.85/32`（VDI 環境 予備）
- 補足: IAM Role は SSM・S3・CloudWatch Logs の最小権限
- 注意: SSH ポート（22）は開放しない（Session Manager 経由）

### TASK-007

- 補足: バックアップ専用の S3 バケット。ライフサイクルで 30 日経過分を自動削除
- 注意: TASK-003 の Terraform バックエンド用バケットとは別バケット

### TASK-008

- 補足: Amazon Linux 2023 前提。inotify・vm.max_map_count・nofile・
  Docker logging driver を要件書 3.6 にしたがって設定
- 注意: IMDSv2 強制をインスタンスメタデータオプションで指定する

### TASK-009

- 補足: t3.xlarge、EBS gp3 150 GB、EIP 付与、IMDSv2 強制

### TASK-010

- 補足: 平日 8:00 起動・22:00 停止（JST）。土日祝は起動しない

### TASK-013

- 補足: 4 ドメイン（gitlab/jenkins/redmine/sonarqube）→ 各サービスポートへのリバプロ設定
- 補足: HTTPS は Let's Encrypt で自動取得・更新（HTTP-01 challenge）

### TASK-014

- 補足: イメージタグはメジャー・マイナーで固定（latest 不使用）。メモリ上限は要件書 3.4 表にしたがう
- 注意: Redmine は TASK-016 のカスタムイメージを参照する

### TASK-015

- 補足: OAuth Client Secret 等の機密値は実値を入れずテンプレート化
- 注意: 実値は SSM Parameter Store（SecureString）または Secrets Manager から注入する

### TASK-016

- 補足: 公式 redmine イメージを拡張し、プラグインの bundle install と
  `redmine:plugins:migrate` を起動時に自動実行する構成にする

### TASK-017

- 補足: 本体マイグレーション後にプラグイン依存解決とマイグレーションを
  実行する entrypoint スクリプト。`redmine-plugins` volume 配下を対象とする

### TASK-018

- 補足: 4 サブドメインへブラウザアクセスし、各サービスのログイン画面到達まで確認
- 進捗（2026-05-29）: ローカルスモークテスト範囲は完了
  （compose 構文検証、`.env` テンプレート整備、SonarQube タグ修正）。
  詳細は `docs/verification-ledger.md` の「TASK-018 ローカル疎通検証の所見」参照
- 残作業: 実機（TASK-012 完了後の t3.xlarge）で 4 サービス起動・
  ブラウザ確認・V-08 メモリ実測。ローカル Docker Desktop での
  起動はメモリ不足（7.6 GB < 13.5 GB）と containerd 画像ストアの
  既知バグにより不可

### TASK-019

- 補足: SAML または OIDC を Entra ID 側のライセンス・運用方針で選択
- 注意: 既存セッション継続のため初回設定時は復旧用ローカル管理者を残す

### TASK-020

- 補足: Jenkins・Redmine・SonarQube 用の Redirect URI は要件書 7.3 節参照
- 注意: Client ID / Secret は TASK-015 の `.env` に反映する

### TASK-021

- 補足: GitLab Authentication Plugin で OAuth 連携
- 注意: GitLab CE 本体とのバージョン互換性を事前確認

### TASK-022

- 補足: redmine_oauth プラグインで OAuth 連携
- 注意: 第三者メンテのため Redmine 本体バージョン対応の追従状況を確認

### TASK-023

- 補足: SonarQube Community Edition の標準 GitLab OAuth 機能を使用

### TASK-025

- 補足: GitLab は `gitlab-backup create`、Jenkins は JENKINS_HOME tar、
  共有 PostgreSQL は `pg_dumpall`（SonarQube DB 除外）、Redmine は files 追加。
  30 日保持のライフサイクルは TASK-007 で設定済
- 注意: SonarQube は対象外

### TASK-026

- 補足: 要件書 6.5 節のロールバックパターン別手順に対応した復元スクリプト
- 注意: DB マイグレーション後のロールバックはタグ巻き戻しだけでは復旧できない前提

### TASK-027

- 補足: バックアップ取得・S3 アップロード・S3 からのダウンロード・復元の一連を検証

### TASK-028

- 補足: docker-compose.yml の image タグを監視し、リリースノート付きで MR 自動作成
- 注意: 反映自体は手動運用（運用窓確保のため）
- 成果物（2026-05-29）: リポジトリルートに `renovate.json` を配置。
  対象は 5 サービス（caddy / gitlab-ce / jenkins / sonarqube / postgres）と
  Redmine の 3 箇所同期（Dockerfile FROM・compose の `args.REDMINE_VERSION`・
  `image: devel-base/redmine:X.Y.Z`）。SonarQube は
  `MAJOR.MINOR.PATCH.BUILD-community` の独自バージョニング、GitLab CE は
  マイナーとパッチを別 PR 化。自動マージは無効（既定）。
  `renovate-config-validator` で構成検証済
- 残作業: GitHub 側で Mend Renovate App をリポジトリに有効化する
  運用作業（リポジトリ管理者が GitHub Apps 画面で実施）

### TASK-029

- 補足: Terraform 実行手順、Docker Compose 初回起動手順、
  SSO/OAuth 設定手順を含める

### TASK-030

- 補足: 起動停止・バックアップ・復旧・アップデートの各手順を
  要件書 5.4 節および 6 節（特に 6.5 節のロールバックパターン）に沿って記載

### TASK-031

- 補足: 要件書 3.1 節のアーキテクチャ図をベースに、ネットワーク構成図
  （VPC・サブネット・SG・EIP・DNS）と Docker コンテナ構成図
  （Caddy 経由のリバプロと 4 サービスの関係）を作成

### TASK-032

- 補足: 対象は Terraform モジュール・Docker Compose・Dockerfile と
  プロジェクト固有ポリシー（SSH 非開放、latest タグ禁止、メモリ上限明示
  などの要件書 6.2・8.2.3 由来の規約）。候補は conftest（OPA/Rego）、
  tflint、tfsec、checkov、hadolint、trivy config 等を比較対象とする
- 注意: shellcheck と markdownlint-cli2 はすでに運用中のため再選定の
  対象外。成果物は採用ツール・運用パターン・既存成果物への適用範囲を
  示した選定メモ
- 成果物（2026-05-29）: `docs/adr/0001-iac-verification-harness.md`。
  採用は案 C（tflint + Trivy + Hadolint + Conftest）。ルールロジック
  記述は Rego（Conftest + Trivy Custom Checks）に統一され、tflint /
  Hadolint は組込ルールの ON/OFF 設定のみで実質 DSL 1 系統に収束する
  ことを判断根拠とした

### TASK-033

- 補足: 設定ファイルをリポジトリに配置し、実行コマンドを
  CLAUDE.md「検証コマンド」節に反映する。既存の Terraform モジュール
  （route53 / backup / ec2_host/user_data）と `compose/docker-compose.yml`・
  `compose/redmine/Dockerfile` に対して全項目パスする状態を完了条件と
  する
- 注意: CI（GitHub Actions 等）への組み込みは別タスク／Backlog として
  扱い、本タスクではローカル実行手順の整備までで完結する

## Backlog一覧

| ID | Status | Summary | DependsOn |
| --- | --- | --- | --- |
| BACKLOG-001 | ⏳ | 初月運用後のコスト実績レポートを作成する | - |
| BACKLOG-002 | ⏳ | 検証用環境（別 EC2 または開発者ローカル）を構築する | - |
| BACKLOG-003 | ⏳ | GitLab CI 上にアップグレード検証パイプラインを構築する | - |
| BACKLOG-004 | ⏳ | t3.2xlarge へのスケールアップ手順を整備する | - |
| BACKLOG-005 | ⏳ | Jenkins 構成を JCasC でリポジトリ管理する | - |

## Backlog詳細

### BACKLOG-001

- 補足: 要件書 12 節の成果物。1 か月分の実コストを集計する
- 注意: M1 完了後に着手

### BACKLOG-002

- 補足: 同一 docker-compose.yml を別 EC2 または開発者ローカルで起動する想定

### BACKLOG-003

- 補足: メジャーアップグレード時の事前検証自動化

### BACKLOG-004

- 補足: メモリ実測値に応じて検討
