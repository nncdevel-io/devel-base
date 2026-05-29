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
| TASK-018 | ✅ | Docker Compose 構文・タグ・env のローカル整合を確定する | TASK-013,TASK-014,TASK-015,TASK-017 |
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
| TASK-034 | ⏳ | 実機 EC2 で Docker Compose を起動し 4 サブドメイン疎通を確認する | TASK-012,TASK-018 |
| TASK-035 | ⏳ | V-08（4 サービス同居時メモリ使用量）を実測しレジャーを更新する | TASK-034 |
| TASK-019 | ⏳ | GitLab と Entra ID の SAML/OIDC SSO を設定する | TASK-034 |
| TASK-020 | ⏳ | GitLab に OAuth Application を 3 件登録する | TASK-019 |
| TASK-021 | ⏳ | Jenkins に GitLab Authentication Plugin で OAuth 認証を設定する | TASK-020 |
| TASK-022 | ⏳ | Redmine に redmine_oauth プラグインで GitLab OAuth を設定する | TASK-020 |
| TASK-023 | ⏳ | SonarQube に GitLab OAuth 認証を設定する | TASK-020 |
| TASK-027 | ⏳ | バックアップ取得とリストアの動作検証を実施する | TASK-025,TASK-026,TASK-034 |
| TASK-029 | ⏳ | 構築手順書を作成する | TASK-012,TASK-034 |
| TASK-030 | ⏳ | 運用手順書（起動停止・バックアップ・復旧・更新）を作成する | TASK-021,TASK-022,TASK-023,TASK-024,TASK-026,TASK-027 |
| TASK-031 | ⏳ | ネットワーク構成図とコンテナ構成図を作成する | TASK-012,TASK-034 |
| TASK-032 | ✅ | IaC 検証ハーネス候補（conftest 等）を比較し採用ツールを選定する | - |
| TASK-033 | ⏳ | 採用ハーネスをリポジトリに組み込み既存成果物で通過させる | TASK-032 |
| TASK-036 | ✅ | 環境設定 YAML（`config/dev.yaml`）のテンプレートを作成する | TASK-001 |
| TASK-037 | ✅ | 要件書 8.3 を「TLS 静的証明書 + S3 配布」に確定する | TASK-006,TASK-007 |
| TASK-038 | ✅ | 要件書 9.4 を「`config/*.yaml` + `aws_s3_object` 配布」に確定する | TASK-036 |
| TASK-039 | ✅ | `gitlab-runner` サービス追加に伴い要件書 3.4・4.x を更新する | TASK-014 |
| TASK-040 | 🚧 | user_data を `templatefile()` 化し systemd unit・cert fetch timer・`.env` 生成を組み込む | TASK-008,TASK-036,TASK-037 |
| TASK-041 | ⏳ | `app_deploy` モジュール（`aws_s3_object` で `compose/` `scripts/` を S3 へ put）を実装する | TASK-007,TASK-014 |
| TASK-042 | ✅ | README.md を利用者視点に再編し、設計詳細を要件書に移行する | TASK-037,TASK-038 |

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

- 補足: 対象は docker-compose.yml 構文検証・`.env` テンプレート整備・
  公式イメージタグの存在性確認まで。実機での 4 サービス起動と
  ブラウザ疎通確認は TASK-034、メモリ実測は TASK-035 に分離
  （2026-05-29 にスコープ確定）
- 注意: ローカル Docker Desktop は containerd 画像ストアの既知バグで
  Jenkins / Redmine の pull が失敗するため、本タスクでは pull 試行
  までで起動は対象外
- 成果物（2026-05-29）: `docker compose config` 通過、SonarQube タグ
  修正（`25.1.0-community` → `25.1.0.102122-community`）。
  詳細は `docs/verification-ledger.md` の「TASK-018 ローカル疎通検証の所見」参照

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

### TASK-034

- 補足: TASK-012 で構築した t3.xlarge 上で `docker compose up -d` 実行、
  caddy / gitlab / jenkins / redmine / sonarqube / postgres の全コンテナ
  Up を確認後、4 サブドメイン
  （gitlab / jenkins / redmine / sonarqube.devel-base.example.com）へ
  ブラウザアクセスし各ログイン画面到達まで確認
- 注意: 本番 AMI（Amazon Linux 2023 + Docker CE）ではローカル
  Docker Desktop の containerd バグは再現しない見込み

### TASK-035

- 補足: `docker stats` 等で 4 サービス同居時のメモリ使用量を 1 時間以上
  サンプリングし、`docs/verification-ledger.md` の V-08 を 📅 → ✅ に更新
- 注意: t3.xlarge 16 GB に対し要件書 3.4 のメモリ上限合計 約 13.5 GB が
  実用上収まるかを判定する。逼迫していれば BACKLOG-004（t3.2xlarge
  スケールアップ）の着手を提案する

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

### TASK-036

- 補足: 環境依存の非機密パラメータ（ドメイン・ゾーン ID・CIDR・バケット名・
  メール・インスタンスタイプ等）を `config/dev.yaml` に集約する。
  Terraform 側は `yamldecode(file(...))` で読み込み、tfvars は原則として
  使わない。機密値（DB パスワード等）は YAML に書かず user_data 側で
  `openssl` 生成する
- 注意: V-01 〜 V-03 の未確定値はプレースホルダ（`<...>`）で書き出し、
  V エントリ確定とともに埋める
- 成果物（2026-05-29）: `config/dev.yaml` を作成。
  project / region / domain / cert / storage / network / contact / ec2 /
  schedule の 9 セクションに分割。`yq eval` で構文 OK

### TASK-037

- 補足: 要件書 8.3 を「Let's Encrypt 自動取得（HTTP-01）」から
  「外部リポジトリの `acme-cert-updater` が S3 配置 → EC2 が systemd timer
  で fetch → Caddy 静的 tls」に書き換える。8.3.1（配布フロー）と
  8.3.2（取り決め）の小節を追加する
- 注意: 証明書取得・更新は本リポジトリの管理対象外。devel-base 側の
  fetch・reload 機構のみを設計範囲とする

### TASK-038

- 補足: 要件書 9.4 を「Systems Manager または Git pull」二択提示から
  「config/*.yaml で環境設定、`aws_s3_object` で `compose/` `scripts/` を
  S3 配布、user_data から fetch して起動」に確定する
- 注意: tfvars は原則使わない方針も同時に明文化する

### TASK-039

- 補足: `compose/docker-compose.yml` に追加した `gitlab-runner` サービス
  （Docker executor、Docker socket bind、mem_limit 512m）を要件書 3.4
  メモリ表に追加し、4.x 機能要件で役割を明記する。リソース合計の見直しと
  3.3 でのスケールアップ閾値の補足も行う
- 注意: gitlab-runner の registration は手作業 Runbook（Phase 3）に
  含める。CI ジョブ実行は Host docker daemon を共有する（DooD）方針

### TASK-040

- 補足: 既存の `user_data.sh`（Docker・OS チューニング）に以下を追加する:
  - `aws s3 sync` で `compose/` `scripts/` を `/opt/devel-base/` に取得
  - `compose/.env` 不在時に `openssl` で機密値を生成
  - 証明書を S3 から fetch して `/opt/devel-base/certs/` に配置
  - `devel-base.service`（systemd unit）と `fetch-cert.timer` を作成・有効化
  - 各値（`domain_base` / `cert_s3_bucket` / `cert_s3_prefix` 等）は
    `templatefile()` で YAML 値から注入
- 注意: cloud-init は初回 boot のみ user_data を実行する（V-09 詳細）。
  2 回目以降は systemd unit が `docker compose up -d` を担保する

### TASK-041

- 補足: `terraform/modules/app_deploy/` を新規作成し、リポ内の `compose/`
  `scripts/` を `aws_s3_object` で `for_each = fileset(...)` を使って一括
  put する。`aws_instance` から `depends_on` で参照することで初回 boot
  までに S3 上のファイルが揃う状態を保証する
- 注意: `terraform.tfvars` を使わない方針と整合させ、YAML から渡される
  バケット名・prefix を受ける

### TASK-042

- 補足: README.md は利用者（開発者）向けの記載に絞り、設計の詳細
  （配布方式・user_data の動作・TLS 取得経路・systemd unit）は要件書
  および `docs/runbook/` に移す。README は「サービス URL、ログイン方法、
  稼働時間、問い合わせ、ドキュメントへの導線」を中心とする
- 注意: ドメインが未確定のため、URL はプレースホルダで書く

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
