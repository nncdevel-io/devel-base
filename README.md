# devel-base

開発に必要なツール群（GitLab・Jenkins・Redmine・SonarQube）を社内向けに
集約して提供する開発基盤です。

## 提供サービス

| サービス | URL | 用途 |
| --- | --- | --- |
| GitLab CE | `https://gitlab.<domain>` | リポジトリ、Issue、Merge Request、GitLab CI |
| Jenkins | `https://jenkins.<domain>` | CI/CD パイプライン |
| Redmine | `https://redmine.<domain>` | プロジェクト管理、Issue |
| SonarQube | `https://sonarqube.<domain>` | コード品質分析 |

GitLab CI 用の Runner は GitLab CE と同居しており、ジョブはホスト側の
Docker daemon を共有して実行されます。

## ログイン

GitLab を Identity Provider として全サービスに OAuth 連携しています。

1. GitLab に Entra ID（SAML / OIDC）でサインインする
2. 他サービスは GitLab OAuth で自動連携、初回のみ承認ダイアログが出る

初回ログインの個別手順は `docs/runbook/`（作成予定）を参照してください。

## 稼働時間

平日 8:00 - 22:00 JST。時間外と週末は停止しており、起動停止は
EventBridge Scheduler が自動で実施します。緊急時の手動起動は運用窓口へ。

## 問い合わせ

- 障害・利用相談: `<運用者連絡先>`
- バグ・改善要望: 各サービスの Issue、または devel-base リポジトリの Issue

## ドキュメント

詳細な設計・運用情報は以下を参照してください。

- 要件・設計: [docs/requirements.md](docs/requirements.md)
- タスク状況: [docs/task.md](docs/task.md)
- 要検証事項: [docs/verification-ledger.md](docs/verification-ledger.md)
- 環境設定: [config/dev.yaml](config/dev.yaml)
- 運用 Runbook: `docs/runbook/`（作成予定）

## ライセンス

社内利用限定。
