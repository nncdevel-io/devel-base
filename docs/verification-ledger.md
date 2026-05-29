# 要検証事項台帳

要件書 11.1 節の要検証事項を台帳化したもの。
TASK-001 の成果物。

## ステータス表記

| Status | 意味 |
| --- | --- |
| ✅ | 確定済 |
| 🧪 | 確認依頼中 |
| ⏳ | 未着手 |
| 📅 | 構築後に実測・確認 |

## 検証事項一覧

| # | 項目 | Status | 確認先 | 現状値・備考 |
| --- | --- | --- | --- | --- |
| V-01 | Entra ID アプリ登録権限・ライセンス | ⏳ | 情シス（Entra ID 管理者） | SAML/OIDC 双方の可否、Premium ライセンス有無 |
| V-02 | VPC CIDR 選定（既存 VPC・オンプレ非重複） | ⏳ | ネットワーク担当 | 候補: `10.x.0.0/24`（x は払い出し依頼） |
| V-03 | 接続元 IP（社内 NAT IP）の固定性・払い出し台帳 | ✅ | （ユーザ提示済） | V-03 詳細表参照 |
| V-04 | セキュリティポリシー（SCP・Config 等）との整合性 | ⏳ | クラウドガバナンス担当 | EC2 タイプ制限・S3 暗号化必須等の確認 |
| V-05 | バックアップ取得時の GitLab 瞬断許容可否 | ⏳ | 利用者代表 | `gitlab-backup create` 実行中の動作確認 |
| V-06 | GitLab Authentication Plugin と GitLab CE のバージョン互換性 | ⏳ | 構築担当（自分） | 採用 GitLab CE バージョン確定後に確認 |
| V-07 | redmine_oauth プラグインと Redmine 本体バージョン追従状況 | ⏳ | 構築担当（自分） | 採用 Redmine バージョン確定後に確認 |
| V-08 | t3.xlarge での 4 サービス同居時のメモリ使用量 | 📅 | 構築担当（自分） | 構築後に実測（TASK-018 以降） |

## V-03 詳細: 社内 IP CIDR

Security Group Inbound（443/80）で許可する社内 IP。

| CIDR | 用途 |
| --- | --- |
| `118.238.15.65/32` | 汐留インターネットゲートウェイ |
| `121.83.239.1/32` | 中之島インターネットゲートウェイ |
| `3.114.145.178/32` | gitlab.nncdevel.io |
| `20.89.59.132/32` | VDI 環境 |
| `20.89.58.85/32` | VDI 環境（予備） |

## 完了条件

- すべての項目が ✅ または 📅 になっていること
- ⏳ または 🧪 が残っている場合は本タスクは未完了

## 関連タスク

- TASK-001: 本台帳の作成・更新
- TASK-004: V-02（VPC CIDR）確定後に着手可能
- TASK-005: V-03（社内 IP CIDR）を反映
- TASK-018: V-08（メモリ実測）の起点
- TASK-019: V-01（Entra ID）確定後に着手可能

## TASK-018 ローカル疎通検証の所見（2026-05-29）

要件書 3.3 では本番 EC2 が t3.xlarge（16 GB）。ローカル検証は
構築前のスモークテストとして実施した。

### 検証済み事項

- `docker compose config`: 構文エラーなし（環境変数解決後 exit=0）
- `caddy:2`, `postgres:15` イメージ pull 成功
- `compose/.env` をテンプレートから生成し DOMAIN_BASE=localhost
  で Caddy 内部 CA 経由のローカル疎通を想定可能

### 構成上の修正

| # | 項目 | 修正前 | 修正後 | 理由 |
| --- | --- | --- | --- | --- |
| F-01 | SonarQube イメージタグ | `sonarqube:25.1.0-community` | `sonarqube:25.1.0.102122-community` | Docker Hub に前者のタグは存在せず、Community Edition はビルド番号付きのみ公開されているため |

F-01 に伴う論点: SonarQube Community のタグはビルド番号必須で、
要件書 6.2 のメジャー.マイナー固定方針と完全には整合しない。
TASK-028（Renovate Bot）でのバージョン追従ロジックで明示的に
扱う必要がある。

### ローカル検証で完了しなかった事項

- `redmine:5.1.4`, `redmine:5.1.5`, `jenkins/jenkins:2.479.2-lts`
  の pull が Docker Desktop の containerd 画像ストアで
  「unexpected commit digest ... failed precondition」エラー
  となり失敗。amd64/arm64 双方で再現
  - 同じレジストリ・同じ Docker Desktop で
    `caddy:2`, `postgres:15`, `alpine:3.20` は正常 pull できる
  - これは特定イメージレイヤと containerd snapshotter の相性
    問題で、`Settings → General → Use containerd for pulling
    and storing images` を OFF にして再起動するか、本番 EC2
    （Amazon Linux 2023、Docker CE 直接インストール）で実施する
    ことで回避可能と推測される
- ホスト Docker メモリ 7.6 GB に対し本構成のメモリ上限合計は
  約 13.5 GB。GitLab（5 GB）と SonarQube（3 GB）が大きく、
  4 サービス同時起動はローカル不可
- 4 サブドメインへのブラウザアクセス確認（TASK-018 補足の
  完了条件）は GUI 操作を伴うためエージェントでは実施不可

### 推奨対応

- TASK-018 の最終 ✅ 化は **TASK-012（AWS 一式構築）完了後の
  実機検証時** に行う。ローカルでの構文・タグ・envテンプレートの
  検証は完了として、ステータスは 🧪（確認待ち）に留める
- V-08（メモリ実測）は TASK-018 実機検証フェーズで採取する
