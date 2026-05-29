# devel-base 開発環境 IaC 要件書

## 1. 概要

GitLab・Jenkins・Redmine・SonarQube からなる開発環境
「**devel-base**」を AWS 上に構築する Infrastructure as Code
(IaC) の要件を定義する。
社内利用者数名規模で運用可能な、コスト最小化を最優先した構成とする。

devel-base は「開発の基地（development base）」を意味し、
開発に必要なツール群を 1 つの拠点に集約する構成思想を表す。

本構成では、以下の 3 つを設計上の最重要観点とする。

1. EC2 1 台で 4 サービスを運用できること
2. バージョンアップを継続的に・安全に実施できること
3. 社内 IP 制限による最小限のセキュリティ境界

## 2. 前提・制約条件

### 2.1 前提条件

- クラウドプロバイダ: AWS（東京リージョン: ap-northeast-1）
- IaC ツール: Terraform
- 既存リソース:
  - AWS アカウント: 既存アカウントを利用
- 新規作成リソース:
  - VPC: 本環境専用に新規作成
- 利用規模: 数人（10 名以下）

### 2.2 制約条件

- アクセス制御:
  - 社内からのインターネット経由アクセスのみ許可
  - 接続元 IP アドレスでの制限を実施
  - 社外からのアクセスは Deny
- コスト方針: 最小化を最優先。ただし以下は採用しない
  - スポットインスタンス
  - Graviton（Arm）インスタンス
  - Savings Plans / Reserved Instances
- 稼働時間: 平日 8:00-22:00（JST）。時間外は停止
- 認証:
  - GitLab を Microsoft Entra ID と SSO 連携
  - Jenkins・Redmine・SonarQube は GitLab OAuth で認証委譲
- バックアップ:
  - GitLab・Jenkins・Redmine: 日次バックアップ必須
  - SonarQube: バックアップ不要
- 監視: CloudWatch のみ（外部 SaaS 連携なし）

## 3. アーキテクチャ方針

### 3.1 基本方針: 単一 EC2 上の Docker Compose 構成

1 台の EC2 上に Docker Compose で全サービスを稼働させる。

```text
        Internet
            │ HTTPS (443) + HTTP (80, Let's Encrypt用)
            │ Security Group で社内 IP CIDR のみ許可
            ▼
    ┌───────────────────────┐
    │ devel-base-host       │
    │ (EC2 t3.xlarge + EIP) │
    │ ┌───────────────────┐ │
    │ │ Docker Compose    │ │
    │ │ ┌───────────────┐ │ │
    │ │ │ Caddy         │ │ │ ← リバプロ + Let's Encrypt
    │ │ ├───────────────┤ │ │
    │ │ │ GitLab CE     │ │ │
    │ │ │ Jenkins       │ │ │
    │ │ │ Redmine       │ │ │
    │ │ │  └─ MySQL     │ │ │
    │ │ │ SonarQube     │ │ │
    │ │ │  └─ PostgreSQL│ │ │
    │ │ └───────────────┘ │ │
    │ └───────────────────┘ │
    │  EBS gp3 (named vols) │
    └───────────────────────┘
```

### 3.2 アーキテクチャ選択の根拠

「ローカル稼働（EC2 直インストール）」と「コンテナ稼働（Docker
Compose）」を比較した結果、**コンテナ稼働を採用する**。
最大の決定要因はバージョンアップ容易性である。

#### 3.2.1 ローカル稼働 vs コンテナ稼働

| 観点 | EC2 直インストール | Docker Compose |
| --- | --- | --- |
| Ruby ランタイム管理 | rbenv/asdf 等で手動切替、依存衝突あり | コンテナ内に閉じ込め、ホスト無影響 |
| Java ランタイム管理 | OS パッケージで衝突しやすい | 同上 |
| バージョンアップ手順 | パッケージマネージャ + 手動移行 | イメージタグ変更 + `up -d` |
| ロールバック | 困難（バックアップから手動復元） | タグを戻して `up -d`、データはvolume |
| 検証環境の再現性 | 困難（ホスト依存） | 同一 compose ファイルで再現 |
| 依存解決 | bundler / apt の競合に苦しむ | コンテナ単位で隔離 |
| 性能オーバーヘッド | なし | 数 % 程度（実用上問題なし） |
| 公式イメージ利用 | 不可 | 4 サービスすべて公式イメージあり |

GitLab と Redmine が Ruby ベースであることが本構成における
バージョンアップの最大の難所であり、コンテナ化によって Ruby
ランタイムを完全にコンテナ内へ閉じ込めるメリットが極めて大きい。

#### 3.2.2 Docker のパフォーマンス影響

| 領域 | オーバーヘッド | 備考 |
| --- | --- | --- |
| CPU | ほぼゼロ（< 1%） | cgroup + namespace のみで仮想化なし |
| メモリ | ほぼゼロ | ホストカーネル共有 |
| ディスク I/O（volume 経由） | ほぼゼロ | ホストの FS を直接利用 |
| ネットワーク（コンテナ間） | 数 % | 同一ホスト内のため sub-ms |
| ネットワーク（外部→コンテナ） | 数 % | Caddy 経由で 1 hop 増 |

数人規模の利用において体感できる劣化は発生しないと判断する。

### 3.3 EC2 インスタンス構成

EC2 インスタンスは **1 台のみ** とする。

| 項目 | 内容 |
| --- | --- |
| 用途 | 4 サービス + Caddy 同居 |
| インスタンスタイプ | t3.xlarge |
| vCPU | 4 |
| メモリ | 16 GB |
| ストレージ | 150 GB gp3（OS 30 GB + データ 120 GB） |

リソース不足の兆候があれば t3.2xlarge（32 GB）へスケールアップ
可能とする。スケールアップの典型トリガー:

- 4 サービス常駐分の合計メモリが安定的に 12 GB を超える
- GitLab Runner の同時 CI ジョブ数（DooD 経由でホスト側に起動するため
  常駐分とは別に消費）でメモリ・CPU が逼迫する
- Jenkins ビルド負荷が GitLab Runner と重なる時間帯で持続的に高負荷

### 3.4 コンテナ構成

| コンテナ | イメージ | メモリ上限 |
| --- | --- | --- |
| Caddy | caddy:2.11.3 | 256 MB |
| GitLab CE | gitlab/gitlab-ce:19.0.1-ce.0 | 5 GB |
| GitLab Runner | gitlab/gitlab-runner:v19.0.0 | 512 MB |
| Jenkins | jenkins/jenkins:2.555.2-lts | 3 GB |
| Redmine | redmine:6.1.2（公式イメージをベースに devel-base/redmine としてビルド） | 1 GB |
| SonarQube | sonarqube:26.5.0.122743-community | 3 GB |
| PostgreSQL（Redmine/SonarQube 共有） | postgres:18 | 1 GB |

OS + Docker + 予備で約 2 GB を確保し、合計 16 GB に収める。
GitLab と SonarQube が大きいため、Jenkins ビルド時のリソース
競合に注意が必要。

### 3.5 データ永続化

- 各サービスのデータは Docker named volume に保存
- volume の実体は EBS 上の `/var/lib/docker/volumes` 配下
- 永続化対象:
  - GitLab: config・data・logs
  - Jenkins: JENKINS_HOME
  - Redmine: files（添付ファイル）・plugins・config
  - SonarQube: data・extensions（プラグイン）
  - PostgreSQL: data（Redmine/SonarQube の DB を共有）
  - Caddy: data（Let's Encrypt 証明書）・config

### 3.6 OS チューニング

Docker 自体ではなく、複数サービス同居に伴って必要となる設定。

| 項目 | 設定値 | 理由 |
| --- | --- | --- |
| `fs.inotify.max_user_watches` | 524288 | GitLab・SonarQube のファイル監視 |
| `fs.inotify.max_user_instances` | 8192 | 同上 |
| `vm.max_map_count` | 262144 | SonarQube 内 Elasticsearch 要件 |
| `nofile`（ulimit） | 65536 | 多数のソケット・ファイル使用 |
| Docker logging driver | json-file（max-size=10m, max-file=3） | ログ無限肥大の防止 |

## 4. 機能要件

### 4.1 GitLab

- ソースコード管理（Git）
- マージリクエスト・コードレビュー
- Webhook による Jenkins 連携
- Entra ID による SSO（SAML または OIDC）
- OAuth プロバイダとして Jenkins・Redmine・SonarQube に
  認証を提供
- GitLab CI 用 Runner を同居（後述）

### 4.1.1 GitLab Runner

- GitLab CI 用の Runner を同一 EC2 上の docker-compose に同居させる
- Executor は **Docker executor**、ホストの Docker socket をマウントする
  方式（Docker-out-of-Docker / DooD）。CI ジョブのコンテナはホスト
  Docker daemon 上に sibling として起動する
- DinD（Docker-in-Docker）は採用しない（メモリ・速度コスト過剰、
  社内専用のため隔離レベルは DooD で十分）
- 同時実行ジョブ数は config.toml の `concurrent` で 2 程度に絞り、
  暴走時の被害範囲を限定する
- 初回 Runner 登録は手作業（Phase 3 の Runbook）
  - `docker compose exec gitlab-runner gitlab-runner register \
    --url https://gitlab.${DOMAIN_BASE} --registration-token <TOKEN>`
- DooD のセキュリティ運用ルール:
  - CI 実行可能なユーザを GitLab プロジェクトメンバーに絞る
  - `.gitlab-ci.yml` のコードレビューを徹底する
  - 信頼できない外部 PR を CI に流す運用は禁止

### 4.2 Jenkins

- CI/CD パイプライン実行
- GitLab Webhook によるジョブ起動
- SonarQube Scanner 連携
- GitLab OAuth による認証（GitLab Authentication Plugin）
- エージェント分離なし（コントローラ単体で実行）

### 4.3 Redmine

- 課題管理・進捗管理
- GitLab とのリポジトリ連携（リビジョン参照）
- GitLab OAuth による認証（redmine_oauth プラグイン）
- **プラグインの bundle install および db migration をコンテナ起動時に
  自動実行する**（カスタム Dockerfile で公式イメージを拡張）

### 4.4 SonarQube

- 静的解析
- Jenkins からのスキャン結果受領・可視化
- GitLab OAuth による認証（Community Edition 標準機能）

## 5. 非機能要件

### 5.1 可用性

- Single-AZ
- インスタンス障害時はバックアップから手動復旧
- 稼働時間: 平日 8:00-22:00 JST

### 5.2 性能

- 利用者数名のため大規模対応不要
- Jenkins 同時ビルド: 2 程度を想定
- リソース競合発生時は t3.2xlarge へスケールアップ

### 5.3 セキュリティ

- 通信: HTTPS（Caddy + Let's Encrypt で自動取得・更新）
- IP 制限: Security Group の Inbound で社内 NAT IP CIDR のみ許可
- IAM:
  - EC2 にアタッチする IAM Role は最小権限
  - 運用者は既存の IAM Identity Center 経由でアクセス
- IMDSv2 を強制
- SSH は開放せず、Session Manager 経由で接続
- Docker コンテナは非 root ユーザで実行（公式イメージの標準に従う）

### 5.4 運用

- 起動停止:
  - EventBridge Scheduler で平日 8:00 起動・22:00 停止
- バックアップ:
  - GitLab: 日次で `gitlab-backup create` 実行後 S3 へ転送
  - Jenkins: 日次で JENKINS_HOME を tar アーカイブし S3 へ転送
  - Redmine: 日次で files ディレクトリを S3 へ転送
  - PostgreSQL: 日次で `pg_dumpall` を S3 へ転送（Redmine の DB 含む。
    SonarQube DB はリストア対象外として `--exclude-database=sonarqube` で除外）
  - SonarQube: なし（アプリ・DB ともに）
  - 補助的に EBS スナップショットを日次取得
- 保持期間: 30 日（S3 ライフサイクルで自動削除）

## 6. バージョンアップ戦略

本要件書の中核セクション。GitLab・Redmine の Ruby 依存問題を
含めた継続的アップグレードを実現する仕組みを定義する。

### 6.1 基本原則

1. **イメージタグはバージョン固定**: `latest` は使用しない
2. **設定は Git 管理**: `docker-compose.yml`・`Caddyfile`・
   `.env.example` をリポジトリ管理
3. **データは volume 分離**: コンテナ再作成でデータ消失しない
4. **更新前に必ずバックアップ**: 手順に組み込む
5. **ロールバック方針はパターン別**: タグを戻すだけで済むのは
   DB 変更を伴わないパッチ更新のみ。マイナー以上の更新は
   バックアップからの DB 復元を前提とする（6.5 節参照）

### 6.2 イメージタグ管理

`docker-compose.yml` に以下のようにメジャー.マイナーで固定する。

```yaml
services:
  gitlab:
    image: gitlab/gitlab-ce:19.0.1-ce.0
  redmine:
    image: devel-base/redmine:6.1.2   # Dockerfile で redmine:6.1.2 を拡張
  jenkins:
    image: jenkins/jenkins:2.555.2-lts
  sonarqube:
    image: sonarqube:26.5.0.122743-community
  postgres:
    image: postgres:18
```

### 6.3 アップデート検知の自動化

GitLab CI と Renovate Bot（または同等の仕組み）を組み合わせ、
新バージョン検知時に Merge Request を自動作成する。

- Renovate が docker-compose.yml のイメージタグを監視
- 新バージョンを検知すると MR を作成（リリースノート付き）
- 担当者が MR レビュー → 検証 → マージ
- マージ後の反映は手動（運用窓を確保するため）

### 6.4 標準アップデート手順

```bash
# 0. 事前バックアップ実行（自動バックアップとは別に手動取得）
./scripts/backup-all.sh

# 1. 最新の compose 設定取得
git pull

# 2. 新イメージ取得
docker compose pull

# 3. サービス停止
docker compose down

# 4. 再起動（マイグレーションは公式イメージが entrypoint で自動実行）
docker compose up -d

# 5. ヘルスチェック
./scripts/healthcheck.sh
```

各公式イメージの起動時挙動:

- GitLab: `gitlab-ctl reconfigure` 相当が自動実行され、
  同期 DB マイグレーションを実行。Batched Background Migration は
  別途バックグラウンドで進行（後述）
- Redmine: 公式 entrypoint が本体 `db:migrate` を自動実行。
  さらに本構成のカスタム Dockerfile によりプラグインの
  `bundle install` と `redmine:plugins:migrate` も自動実行
- Jenkins: プラグイン互換チェックが起動時に走る
- SonarQube: DB マイグレーションが自動実行

### 6.5 ロールバック手順

ロールバックは更新の種類によって難易度が大きく異なる。
DB マイグレーションが走った後はイメージタグを戻すだけでは
復旧できないため、パターン別に手順を定義する。

#### 6.5.1 ロールバック可能性のパターン分け

| 更新の種類 | 例 | ロールバック方法 |
| --- | --- | --- |
| パッチ更新（DB 変更なし） | 17.6.1 → 17.6.2 | **タグを戻すのみ**で復旧可能 |
| パッチ更新（DB 変更あり） | 17.6.1 → 17.6.3（migration 含む） | バックアップからの DB 復元必須 |
| マイナー更新 | 17.5 → 17.6 | バックアップからの DB 復元必須 |
| メジャー更新 | 16.x → 17.0 | バックアップからの DB 復元必須 |

リリースノートで DB マイグレーションの有無を事前確認し、
ロールバック計画を立てる。GitLab・Redmine・SonarQube は基本的に
マイナー以上で DB 変更を伴う前提で扱う。

#### 6.5.2 パッチ更新（DB 変更なし）のロールバック

最もシンプルなケース。タグを戻すだけで復旧可能。

```bash
# 1. docker-compose.yml のタグを前バージョンに戻す
git checkout HEAD~1 -- docker-compose.yml

# 2. 旧イメージで再起動
docker compose pull
docker compose up -d

# 3. ヘルスチェック
./scripts/healthcheck.sh
```

#### 6.5.3 DB マイグレーション後のロールバック

DB スキーマが新バージョン用に変更されているため、旧バージョンを
起動しても **新スキーマを旧コードが読めず、起動失敗または
データ破損** に繋がる。必ずバックアップから DB を復元する。

```bash
# 1. サービス停止
docker compose down

# 2. docker-compose.yml のタグを前バージョンに戻す
git checkout HEAD~1 -- docker-compose.yml

# 3. DB を含むデータをバックアップから復元
# GitLab の例:
docker compose up -d gitlab-postgres  # DB だけ先に起動
docker compose run --rm gitlab gitlab-backup restore \
  BACKUP=<timestamp> force=yes

# Redmine の例（共有 PostgreSQL の redmine DB のみ復元）:
docker compose up -d postgres
docker compose exec -T postgres \
  psql -U "${POSTGRES_USER}" -d "${REDMINE_DB_NAME}" \
  < /backups/redmine/redmine-<timestamp>.sql

# 4. 全サービス起動
docker compose up -d

# 5. ヘルスチェック
./scripts/healthcheck.sh
```

#### 6.5.4 ロールバックを実用的に保つための運用方針

- アップグレード**直前**に必ず手動バックアップを取得する
  （日次バックアップに頼らない）
- バックアップ取得後 30 分以内にアップグレードを開始する
  （その間のデータ変更を最小化するため）
- アップグレード窓を**業務時間外に確保**し、問題発生時に
  ロールバック作業の時間を取れるようにする
- パッチ更新と マイナー/メジャー更新は別運用とし、
  リスクレベルを明示する

#### 6.5.5 ロールバック不可能なケースの認識

以下のケースでは厳密なロールバックは事実上不可能で、
バックアップ取得時点までのロールフォワード復旧となる。

- バックアップ取得後にユーザが投入したデータ
- 認証連携設定の変更後に発生したアカウント連携
- Jenkins ビルド履歴の追加分

このリスクを許容できない変更（特に GitLab メジャー版）は、
**検証環境での事前検証**（6.9 節）を強く推奨する。

### 6.6 GitLab Background Migration の事前確認（必須）

GitLab には起動時に実行される同期マイグレーション以外に、
**Batched Background Migration** という Sidekiq によって裏で
段階実行されるマイグレーションが存在する。前バージョンで投入された
Background Migration がすべて完了する前に次バージョンへ上げると、
新バージョンが起動拒否する仕様のため、アップグレード前に
完了確認が必須となる。

確認方法:

- Web UI: 管理者エリア → Monitoring → Background Migrations で
  すべて "Finished" であることを確認
- CLI:

```bash
docker compose exec gitlab gitlab-psql -c \
  "SELECT job_class_name, status_name \
   FROM batched_background_migrations \
   WHERE status NOT IN (3);"
# 結果が 0 行であれば OK（status=3 が finished）
```

数人規模であれば完了まで数分〜数十分が想定されるが、長期間
アップグレードを怠るとマイグレーションが積み上がり、完了待ち
時間が大きく伸びる。本要件書 6.7 節の定期更新方針はこの対策でも
ある。

### 6.7 メジャーバージョンアップへの対応

特に **GitLab** はメジャーバージョンを跨ぐ際にアップグレード
パスの遵守が必須（例: 16.x の最終版 → 17.0 →
17.x 最新、という順序）。これに対応するため:

- 月次または四半期での定期更新を運用フローに組み込む
- 長期間放置せず、こまめに上げることで段階を踏める状態を維持
- 公式のアップグレードパス表を確認の上で手順を作成

### 6.8 プラグイン互換性管理

Redmine と Jenkins は外部プラグインに依存する。

- **Redmine プラグイン**:
  - プラグインは Docker volume `redmine-plugins` に配置
  - カスタム Dockerfile（`compose/redmine/Dockerfile`）が
    起動時に `bundle install` と `redmine:plugins:migrate` を
    自動実行する
  - プラグインの追加・更新は volume 内のソース更新後に
    コンテナを再起動するだけで完結
  - `redmine_oauth` は本体バージョン対応を必ず確認
- **Jenkins プラグイン**: Jenkins LTS とプラグイン互換性に注意。
  プラグイン構成は Configuration as Code (JCasC) で
  リポジトリ管理することを推奨
- **SonarQube プラグイン**: 本構成では Community 標準機能のみ使用

プラグインのバージョン情報も Git 管理し、本体と同時にレビューする。

### 6.9 検証環境

本番と同じ docker-compose.yml を別 EC2（または開発者ローカル）で
立ち上げ、本番反映前に検証する。これは IaC とコンテナ化に
よって追加コストなしで実現可能。

## 7. 認証・認可

### 7.1 認証フェデレーション方針

GitLab を Identity Bridge として位置付け、4 サービスの認証を
連鎖させる。

```text
[Entra ID] --SAML/OIDC--> [GitLab] --OAuth--> [Jenkins]
                                  |--OAuth--> [Redmine]
                                  \--OAuth--> [SonarQube]
```

### 7.2 サービス別連携方式

| サービス | IdP | プロトコル | 実装 |
| --- | --- | --- | --- |
| GitLab | Entra ID | SAML または OIDC | OmniAuth |
| Jenkins | GitLab | OAuth 2.0 | GitLab Authentication Plugin |
| Redmine | GitLab | OAuth 2.0 | redmine_oauth プラグイン |
| SonarQube | GitLab | OAuth 2.0 | Community Edition 標準機能 |

### 7.3 GitLab OAuth Application 登録

GitLab に OAuth Application を 3 つ登録する。Redirect URI は
それぞれ以下のとおり。

- Jenkins:
  `https://jenkins.devel-base.example.com/securityRealm/finishLogin`
- Redmine:
  `https://redmine.devel-base.example.com/oauth2callback`
- SonarQube:
  `https://sonarqube.devel-base.example.com/oauth2/callback/gitlab`

### 7.4 留意事項

- GitLab を認証ハブとするため、GitLab コンテナ停止中は他 3
  サービスへの新規ログインも不可（既存セッションは継続）
- Redmine の OAuth プラグインは本体バージョンへの追従が必要
  （第三者メンテのため）

## 8. AWS リソース構成

### 8.1 利用サービス一覧

| カテゴリ | サービス | 用途 |
| --- | --- | --- |
| Compute | EC2（t3.xlarge オンデマンド） | 全サービス同居ホスト |
| Storage | EBS gp3 | データ永続化 |
| Storage | S3 | バックアップ保管 |
| Network | VPC（新規） | 専用ネットワーク |
| Network | Internet Gateway | インターネット接続 |
| Network | VPC Endpoint（S3 Gateway） | S3 通信の VPC 内化 |
| Network | EIP | EC2 固定 IP |
| Network | Security Group | IP 制限・通信制御 |
| DNS | Route 53 | 名前解決 |
| Identity | IAM | EC2 ロール・運用者権限 |
| Identity | Entra ID（外部） | SSO IdP |
| Schedule | EventBridge Scheduler | 起動停止 |
| Logging | CloudWatch Logs | OS・コンテナログ |
| Monitoring | CloudWatch メトリクス | リソース監視 |
| Operation | Systems Manager | 構成管理・SSH 代替 |

ALB・ACM は使用しない（Caddy + Let's Encrypt で代替）。

### 8.2 ネットワーク構成

#### 8.2.1 VPC・サブネット

- VPC CIDR: `10.x.0.0/24`（既存 VPC・オンプレと重複しない範囲）
- パブリックサブネット 1 個
  - `10.x.0.0/26`（ap-northeast-1a）
- プライベートサブネットは作らない
- EC2 は本サブネットに配置し EIP を付与

#### 8.2.2 ルーティング

- Internet Gateway を VPC にアタッチ
- パブリックルートテーブル: `0.0.0.0/0` → IGW
- S3 用 Gateway VPC Endpoint を設定（無料・転送費削減）

#### 8.2.3 Security Group

EC2 にアタッチする SG は 1 つ。

- Inbound:
  - 443/TCP: 社内 NAT IP CIDR から許可
  - 80/TCP: 社内 NAT IP CIDR から許可（Let's Encrypt 用）
- Outbound: 全許可

### 8.3 HTTPS 終端・ルーティング

- Caddy コンテナが HTTPS 終端 + 4 ドメインのリバプロを担当
  - `gitlab.devel-base.example.com` → GitLab:80
  - `jenkins.devel-base.example.com` → Jenkins:8080
  - `redmine.devel-base.example.com` → Redmine:3000
  - `sonarqube.devel-base.example.com` → SonarQube:9000
- Caddyfile は数行で完結（静的証明書を `tls` ディレクティブで指定）

#### 8.3.1 TLS 証明書の配布方式

証明書の取得・自動更新は **本リポジトリの管理対象外** とする。
別リポジトリで運用される `acme-cert-updater`（AWS Lambda + Let's Encrypt
ACME v2 + Route 53 DNS-01）が約 60 日サイクルで証明書を S3 に配置する。
devel-base はその S3 上の証明書を消費する側のみを担当する。

データフロー:

1. 別リポ管理の `acme-cert-updater` が Let's Encrypt から取得した
   ワイルドカード証明書を `s3://<bucket>/<prefix>/<timestamp>/{cert,chain,fullchain,privkey}.pem`
   に保存する
2. EC2 上の systemd timer（`fetch-cert.timer`）が日次で latest 版を
   `/opt/devel-base/certs/` に取得する
3. 証明書ファイルに差分があれば Caddy を SIGHUP でリロードする
4. Caddy は `tls /etc/caddy/certs/fullchain.pem /etc/caddy/certs/privkey.pem`
   で静的にこのパスを参照する

#### 8.3.2 設計上の取り決め

- 証明書ファイルは EC2 ローカル（`/opt/devel-base/certs/`）にのみ
  存在し、EBS の保管時暗号化（AWS マネージドキー）で保護される。
  KMS / Secrets Manager は使用しない
- S3 バケット名・プレフィックスは Terraform 変数で外出しし、将来 DNS /
  証明書管理を別 AWS アカウントへ移すケースに備える
- 初回 boot は user_data が起動時に証明書を取得して Caddy に渡す。
  以後は systemd timer が日次で差分取得・リロードする
- 通常運用で運用者が証明書ファイルに触れる場面は発生しない
- 障害復旧（EC2 再作成）時は user_data が新しい S3 fetch を実行する
  ため、EBS snapshot からの復元なしでも証明書は揃う

### 8.4 DNS

- Route 53 パブリックホストゾーンを利用
- A レコードを EIP に向ける（4 サブドメイン）

## 9. IaC 方針

### 9.1 命名規約

プロジェクト名 `devel-base` を全リソースのプレフィックスとして
統一的に使用する。ただし、利用箇所によって使用可能な文字種が
異なるため、以下の 2 表記を使い分ける。

| 表記 | 用途 | 例 |
| --- | --- | --- |
| `devel-base`（ハイフン） | リポジトリ名・FQDN・Name タグ・S3 バケット名 | `devel-base-host` |
| `devel_base`（アンダースコア） | Terraform 識別子・シェル変数 | `devel_base_network` |

理由: HCL（Terraform）の識別子はハイフンを含められないため、
コード内部の識別子はアンダースコア、外部に露出する名前は
ハイフンとする。これは一般的な慣習に従ったもの。

主要リソースの命名例:

| リソース | 名前 |
| --- | --- |
| VPC | `devel-base-vpc` |
| サブネット | `devel-base-subnet-public-a` |
| EC2 インスタンス | `devel-base-host` |
| Security Group | `devel-base-sg` |
| EIP | `devel-base-eip` |
| S3 バックアップバケット | `devel-base-backup-<account-id>` |
| IAM Role | `devel-base-ec2-role` |
| EventBridge Scheduler | `devel-base-start` / `devel-base-stop` |

FQDN は `<service>.devel-base.example.com` 形式とする。

| サービス | FQDN |
| --- | --- |
| GitLab | `gitlab.devel-base.example.com` |
| Jenkins | `jenkins.devel-base.example.com` |
| Redmine | `redmine.devel-base.example.com` |
| SonarQube | `sonarqube.devel-base.example.com` |

### 9.2 ツール構成

- Terraform を採用
- ステート管理: S3 バックエンド + DynamoDB ロック
- 既存 AWS アカウントは AssumeRole で操作
- VPC は本構成内で新規作成

### 9.3 リポジトリ構成

```text
devel-base/
├── terraform/
│   ├── envs/
│   │   └── dev/
│   │       ├── main.tf
│   │       ├── variables.tf
│   │       └── terraform.tfvars
│   └── modules/
│       ├── network/
│       ├── ec2_host/
│       ├── route53/
│       ├── backup/
│       ├── scheduler/
│       └── security/
├── compose/
│   ├── docker-compose.yml
│   ├── Caddyfile
│   ├── .env.example
│   └── redmine/
│       ├── Dockerfile
│       └── plugin-migrate-and-start.sh
└── scripts/
    ├── backup-all.sh
    ├── restore.sh
    └── healthcheck.sh
```

### 9.4 アプリケーション構成管理

- OS: Amazon Linux 2023
- user_data で Docker Engine・Docker Compose をブートストラップ
- 3.6 節の OS チューニング設定を user_data で適用

#### 9.4.1 環境設定の集約: `config/*.yaml`

環境依存の **非機密** パラメータ（ドメイン・ゾーン ID・CIDR・バケット名・
連絡先・インスタンスタイプ・スケジュール等）は `config/dev.yaml` に集約する。
原則として `*.tfvars` は使用しない。

- Terraform 側は `yamldecode(file("${path.root}/../../../config/dev.yaml"))`
  で読み込み、`locals.config` 経由でモジュールに渡す
- user_data は `templatefile()` で YAML 値を流し込み、EC2 起動時に展開
- 運用スクリプト・ヘルスチェック等の補助ツールも同じ YAML を `yq` で読む
- 多環境対応は `config/prod.yaml` 等を追加するだけで、コードに手を入れない

#### 9.4.2 アプリ構成の配布: `aws_s3_object` + S3

`compose/` と `scripts/` 配下のファイルは Terraform の `aws_s3_object`
リソースで S3 にアップロードする（`for_each = fileset(...)`）。
`aws_instance` は `depends_on = [aws_s3_object.config]` でこれに従属し、
EC2 の first boot 時点で S3 にファイルが揃っている状態を保証する。

```text
[Terraform apply]
  S3 バケット作成
        │
        ▼
  aws_s3_object で compose / scripts を S3 へ put
        │
        ▼
  EC2 起動 → user_data が aws s3 sync で /opt/devel-base/ に取得
        │
        ▼
  docker compose up -d
```

これにより、初期構築は `terraform apply` 1 発で完結する。

#### 9.4.3 機密値の取り扱い

機密値は YAML にも tfvars にも書かない。EC2 上で発生・保持する。

- DB パスワード（POSTGRES / REDMINE / SONARQUBE）と
  `REDMINE_SECRET_KEY_BASE` は user_data が EC2 上で `openssl` 生成し、
  `/opt/devel-base/compose/.env` に書き出す
- `.env` ファイルは EBS 保管時暗号化で保護され、EBS snapshot バックアップ
  に含まれる
- OAuth Client Secret 等のサービス間連携値は Phase 3 の初回 GUI 設定で
  発行し、各サービスの管理画面（GitLab 含む）で設定する
- KMS / Secrets Manager / SSM Parameter Store は使用しない

#### 9.4.4 平時の更新

`compose/` `scripts/` の変更は `terraform apply` で S3 反映 → EC2 上で
SSM Session 経由の手作業で `aws s3 sync` + `docker compose pull && up -d`
を実行する。要件書 6.4 の手順を本配布方式に整合させる。

## 10. コスト試算（概算）

東京リージョン、オンデマンド、稼働時間: 14h × 5 日 × 4.33 週
≒ 303h/月で算出。

| 項目 | 単価 | 月額（USD） |
| --- | --- | --- |
| EC2 t3.xlarge | $0.2176/h × 303h | $65.9 |
| EBS gp3 150 GB | $0.096/GB | $14.4 |
| EBS スナップショット 100 GB | $0.05/GB | $5.0 |
| EIP（停止時間分） | $0.005/h × 約 425h | $2.1 |
| S3 バックアップ 約 15 GB | $0.025/GB | $0.4 |
| Route 53 ホストゾーン | $0.50/月 | $0.5 |
| CloudWatch Logs（少量） | - | $1-3 |
| Data Transfer Out（少量） | - | $1-3 |
| **合計** | - | **約 $90-95/月** |

備考:

- EBS は停止中も課金される
- EIP は EC2 停止中（インスタンスにアタッチ済でも）に課金
- 24/365 稼働の場合は EC2 だけで約 $93/月増となる
- t3.2xlarge に上げた場合、EC2 部分が約 $132/月になる

## 11. リスク・要検証事項

### 11.1 要検証事項

- Entra ID 側のアプリ登録権限・ライセンス
- VPC CIDR の選定（既存 VPC・オンプレネットワークとの非重複確認）
- 接続元 IP（社内 NAT IP）の固定性・払い出し台帳
- 既存アカウントのセキュリティポリシー
  （SCP・Config ルール等）との整合性
- バックアップ取得時の GitLab サービス瞬断許容可否
- GitLab Authentication Plugin（Jenkins）と GitLab CE の
  バージョン互換性
- redmine_oauth プラグインと Redmine 本体バージョンの追従状況
- t3.xlarge での 4 サービス同居時のメモリ使用量実測

### 11.2 既知リスク

- **単一障害点**: 1 台構成のため EC2 障害時は全サービス停止
- **リソース競合**: Jenkins ビルド負荷が高い時に他サービスの
  応答性が低下する可能性
- Single-AZ のため AZ 障害時は復旧に時間を要する
- スケジュール起動失敗時は手動起動が必要
- SonarQube のバックアップ不要要件によりデータ消失時は
  全プロジェクトの再スキャンが必要
- GitLab を認証ハブとするため、GitLab 停止中は他サービスへの
  新規ログインも不可
- **Redmine プラグインの追従性**: redmine_oauth が
  Redmine 本体の新バージョンに対応しない期間が発生しうる。
  該当時は Redmine のアップグレードを保留する判断が必要
- **GitLab メジャーアップグレードパス**: 飛ばし上げ不可。
  定期的な更新を怠ると一気に上げられず、複数回の段階更新が必要
- **ロールバック制約**: DB マイグレーションを伴う更新は、
  単純なイメージタグ巻き戻しでは復旧できず、バックアップからの
  DB 復元が必須。アップグレード直前の手動バックアップ取得と
  業務時間外のアップグレード窓確保で運用カバーする（6.5 節参照）
- **アップグレード直前バックアップ取得後のロスト**: バックアップ
  取得時点から障害発生時点までに投入されたデータは復旧不可

### 11.3 拡張余地

- リソース不足時は t3.2xlarge にスケールアップ
- ビルド頻度増加時は Jenkins を別 EC2 に分離（compose ファイル
  分割で対応可能）
- 可用性要件が発生した場合は ECS/EKS + Multi-AZ + ALB 構成へ移行
- バージョンアップ自動化を進める場合は GitLab CI 上で検証
  パイプラインを構築

## 12. 成果物

- Terraform コード一式
- `docker-compose.yml`・`Caddyfile`・`.env.example`
- バックアップ・リストア・ヘルスチェックスクリプト
- 構築手順書
- 運用手順書（起動停止・バックアップ・復旧・**アップデート**）
- ネットワーク構成図・コンテナ構成図
- コスト実績レポート（初月運用後）
