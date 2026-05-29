# ADR-0001: IaC 検証ハーネスの選定

## ステータス

採用（2026-05-29）

関連タスク: TASK-032（本選定）、TASK-033（リポジトリ組込）

## 結論

- **採用**: tflint + Trivy + Hadolint + Conftest の 4 ツール構成（案 C）
- **ルールロジックは Rego に集約**: Conftest と Trivy Custom Checks が
  どちらも Rego で書けるため、習得対象は実質 1 DSL。
  `.tflint.hcl` と `.hadolint.yaml` は組込ルールの ON/OFF と severity のみ
- **バージョン真実**: `compose/check-iac.yml` の `image:` タグ
- **ローカル実行**: macOS / Linux は `brew install` + 起動時に各 CLI の
  `--version` を真実と突合（不一致なら `brew upgrade` ヒントで exit 1）。
  Windows は `docker compose run` 直叩き
- **CI**: 同じ Compose 定義を実行する最終ゲート（CI 着手は Backlog 候補）
- **Renovate**: 既存の `docker-compose` マネージャが
  `compose/check-iac.yml` の `image:` タグをそのまま追従。
  `customManagers` の追加拡張は不要
- **初期 Conftest ポリシー 4 件**（要件書 6.2 / 3.4 / 8.2.3 由来）:
  latest タグ禁止 / mem_limit 必須 / SSH 非開放 / SG `0.0.0.0/0` 不可

詳細は以下の各節を参照。

## コンテキスト

本リポジトリは Terraform（6 モジュール + envs/dev）、Docker Compose、
Redmine 用カスタム Dockerfile を含む IaC 集合体である。
当初の検証手段は以下のみで、構文・セキュリティ設定・プロジェクト固有
ポリシーが未カバーだった。

| 対象 | 既存検証 | 不足箇所 |
| --- | --- | --- |
| Markdown | `markdownlint-cli2` | なし |
| Shell スクリプト | `shellcheck` + `bash -n` | なし |
| Terraform | `terraform fmt` / `validate` を CLAUDE.md に記載のみ | 静的解析・セキュリティ・プロジェクトポリシー |
| Docker Compose | `docker compose config` のみ | `latest` タグ禁止・メモリ上限必須等のポリシー |
| Dockerfile | なし | 公式ベストプラクティス・シェル品質 |

TASK-014 完了済の `compose/docker-compose.yml` で SonarQube タグが
存在しない値（`25.1.0-community`）だった件は、ハーネスがあれば
コミット時点で検出できた（要件書 6.2 のメジャー.マイナー固定方針）。
この種の事故を以降のモジュール（TASK-004 / 005 / 009 / 010 / 011）で
繰り返さないため、検証ハーネスの導入が必要。

本構成の規模感:

- Terraform モジュール 6 + envs/dev 1（合計 ~30〜40 リソース見込み）
- Compose 1 ファイル（6 サービス）
- Dockerfile 1 ファイル（9 行）
- 社内利用者数名規模・コスト最小化を最優先（要件書 1 章）

## 評価軸

- **領域カバー**: Terraform / Compose / Dockerfile / プロジェクト固有
  ポリシーをどこまで覆えるか
- **保守性**: 採用ツールが今後 1〜2 年活発に保守され、ローカルと CI で
  運用しやすいこと
- **学習コスト**: 既存運用（shellcheck / markdownlint-cli2）と同様、
  単発コマンドで動くこと、DSL の種類を最小化できること
- **拡張性**: 要件書 6.2（latest 禁止）・8.2.3（SSH 非開放）等の
  プロジェクト固有規約をポリシーとして表現できること
- **外部知見への依存可否**: AWS 一般論のセキュリティルール群を
  外部メンテに乗せられるか（社内で育てる量を減らせるか）

## 候補ツール

公式リポジトリ・公式サイトを 2026-05-29 時点で参照した結果。

| ツール | 主領域 | 状態 | カスタムポリシー | 備考 |
| --- | --- | --- | --- | --- |
| `tflint` v0.62.1（2026-05） | Terraform 構文・lint・プロバイダ固有 | 活発 | OPA プラグイン | AWS ruleset プラグインあり |
| `tfsec` | Terraform セキュリティ | メンテナンスモード | Rego | Trivy へ移行推奨 |
| Trivy | IaC misconfig / Secrets / コンテナ脆弱性 | 活発（tfsec 後継） | Rego（Custom Checks） | `trivy config` で IaC 一括、AWS misconfig 200+ ルール内蔵 |
| Checkov | TF / CFN / K8s / Helm / Compose / ARM / CDK | 活発 | Python or YAML graph | 多領域カバーだが Python 依存 |
| Conftest v0.64+ | 構造化データ全般（HCL / YAML / Dockerfile 等） | 活発 | OPA/Rego | 汎用ポリシー実行エンジン |
| Hadolint v2.14.0（2025-09） | Dockerfile + RUN 内 shell | 活発 | カスタムルール限定 | ShellCheck 統合・SARIF 出力 |

## 検討した選択肢

各案で「できること」「できないこと」「保守性」を整理する。
「できないこと」に該当する領域は、ツールを採用しない以上、自前実装するか
人手レビューで補完する必要がある。

### 案 A: Conftest 単独

| 観点 | 内容 |
| --- | --- |
| できること | プロジェクト固有 4 ポリシー（latest 禁止・mem_limit・SSH 非開放・SG 0.0.0.0/0 不可）の自動検査。HCL / YAML / Dockerfile を Rego で横断的に検査できる |
| できないこと | AWS セキュリティ misconfig の組込検出（S3 公開・SG 全開放・IAM ワイルドカード・EBS 未暗号化・IMDSv1 等の 200+ ルール）。Terraform の typo / 非推奨記法 / 命名 lint。Dockerfile の DL30xx 系ベストプラクティス検査・RUN 内 shell 品質チェック |
| 保守性 | バイナリは 1 本。ただし AWS セキュリティ相当の Rego を社内で書き続ける必要があり、ポリシーリポジトリが肥大化する |

### 案 B: Trivy + Conftest

| 観点 | 内容 |
| --- | --- |
| できること | Trivy が AWS misconfig 200+ ルールを内蔵で実行（リリースごとに自動更新）。Conftest がプロジェクト固有 4 ポリシーを担当。学習対象は実質 Rego 1 系統（Trivy Custom Checks も Rego） |
| できないこと | Terraform の typo / 非推奨記法 / 命名 lint の早期検出（terraform plan 時まで発覚を待つ）。Dockerfile の DL30xx 系ベストプラクティス検査・RUN 内 shell 品質チェック |
| 保守性 | バイナリ 2 本。Trivy 側はルール更新を外部にアウトソース。手書き Rego は固有 4 件で済む。Renovate 追従対象も 2 本 |

### 案 C: tflint + Trivy + Hadolint + Conftest

| 観点 | 内容 |
| --- | --- |
| できること | Terraform 構文・lint（tflint）、AWS セキュリティ misconfig（Trivy）、Dockerfile ベストプラクティス（Hadolint）、プロジェクト固有ポリシー（Conftest）の 4 領域すべてを自動検査 |
| できないこと | 主要領域はすべてカバー（カバレッジ最大） |
| 保守性 | バイナリ 4 本、設定 DSL は 3 系統（HCL ベースの `.tflint.hcl` / YAML の `.hadolint.yaml` / Rego）。Renovate 追従本数とルールセットプラグインの追従が増える。CI 実行時間も長い |

### 案 D: Checkov 中心 + Hadolint

| 観点 | 内容 |
| --- | --- |
| できること | Checkov 1 本で TF / CFN / K8s / Helm / Compose を広域カバー。Hadolint で Dockerfile を担当 |
| できないこと | プロジェクト固有規約は Checkov の Python policies / YAML graph で書く必要があり、Rego と比較して移植性・他ツール連携に劣る（Conftest を併用しない前提） |
| 保守性 | Python 依存（実行環境への要求が増える）。Trivy 比でルールセット更新の透明性に差 |
| 棄却理由 | 保守性・移植性で案 B に劣り、Trivy + Conftest の組合せの方が学習・更新のいずれにおいても整理しやすい |

## 決定

**案 C（tflint + Trivy + Hadolint + Conftest）を採用する。**

選定経緯:

- 保守性観点で当初は案 B（Trivy + Conftest, 2 ツール）を推奨候補と
  したが、検討の結果、案 C で問題ないと判断した
- 判断根拠: カスタムルールの作成・テストはすべて Rego（Conftest +
  Trivy Custom Checks）で完結する。`.tflint.hcl` と `.hadolint.yaml`
  はビルトインルールの ON/OFF と severity 設定のみで、ロジック記述は
  不要。実質的な学習対象は **Rego 1 系統に集中**するため、ツール本数が
  4 本でも DSL 習得負担は案 B と大差ない
- 各案の「できること / できないこと」のトレードオフは前節を参照

受容するコスト:

- バイナリ 4 本のバージョン追従（次節の方針で Renovate に組み込む）
- 設定ファイル 3 種（`.tflint.hcl` / `.hadolint.yaml` / `policy/*.rego`）
  の維持。ただし前 2 者は組込ルール選択のみで肥大化しない

### バージョン統一方針

ローカル CLI のバージョンを「揃え方の強制」で管理せず、
**「ずれていたら実行時のガードで気付ける」** 方針に倒す。OS の慣習を
尊重しつつ、ドリフトはスクリプト起動時の検査と CI で捕捉する。

- バージョン固定の真実は `compose/check-iac.yml`（仮称、最終パスは
  TASK-033 で確定）に集約。4 ツールを services として定義し、公式
  Docker イメージのタグを固定する
- 想定する公式イメージ:
  - tflint: `ghcr.io/terraform-linters/tflint:vX.Y.Z`
  - Trivy: `aquasec/trivy:X.Y.Z`
  - Hadolint: `hadolint/hadolint:vX.Y.Z-alpine`
  - Conftest: `openpolicyagent/conftest:vX.Y.Z`
- CI（GitHub Actions 等。Backlog 候補）は上記 Compose を実行し、
  固定タグで検査する。これが最終のバージョン担保
- ローカル実行は OS の慣習に従う:
  - **macOS / Linux**: `brew install tflint trivy hadolint conftest`
    でホストに直接 install（ネイティブ実行で速い）。
    `scripts/check-iac.sh`（bash）は起動時に各 CLI の `--version` を
    取得して `compose/check-iac.yml` のタグと突合し、不一致なら
    `brew upgrade <tool>` 等のヒントを出して exit 1 する
  - **Windows**: `docker compose -f compose/check-iac.yml run --rm
    <tool>` で OS 非依存に実行。Docker タグで完全固定されるため
    バージョン検査は不要（PowerShell / cmd ネイティブから直接呼べる）
- Trivy のミスコンフィグ DB は services 定義内で named volume または
  ホストキャッシュにマウントし、毎回のダウンロードを回避する
- 新バージョン検知は **TASK-028 の Renovate `docker-compose` マネージャ
  が `compose/check-iac.yml` の `image:` タグを既存設定のまま追従**。
  PR の発生が macOS 開発者にとっても `brew upgrade` のトリガになる
- Docker Desktop は本プロジェクトのランタイムとして既に必須なので、
  Windows ルートでも追加の install 要件は発生しない

棄却した代替案:

- ホスト install のみ（pin なし、CI なし、起動時ガードなし）:
  ドリフトを検出する仕組みがどこにも無く、判定が不安定になる
- ローカルは Compose のみ許可（brew 禁止）: macOS / Linux ネイティブの
  iteration が Docker 起動オーバーヘッドぶん遅くなり、ROI が悪い
- bash スクリプトで `docker run` を直叩き: PowerShell / cmd ネイティブで
  動かず、Windows 開発者に bash 環境（WSL2 / Git Bash）を強制する
- mise / asdf 等のツールバージョンマネージャ: バージョン乖離は解決
  するが、プロジェクトの「Docker 集約」方針と二重化し、新たな
  習得対象を招くため見送り

## 結果

### 得られるもの

- Terraform 構文・命名 lint（tflint）、AWS セキュリティ misconfig
  （Trivy）、Dockerfile ベストプラクティス（Hadolint）、プロジェクト
  固有ポリシー（Conftest）の 4 領域がすべて自動検査される
- TASK-014 で発覚した SonarQube タグ事故と同種の事象を、以降の
  Terraform モジュール追加時に自動検出できる
- AWS 一般論のセキュリティ misconfig は Trivy の外部更新に乗るため
  社内メンテ対象が少ない
- 要件書のセキュリティ要件（SSH 非開放等）が変更レビューで自動検査
  され、人手レビューの負荷が下がる

### コスト

- 公式 Docker イメージ 4 種のタグ管理 + Rego ポリシー初期 4 件の
  作成（TASK-033）
- 4 イメージタグのバージョン追従（TASK-028 の Renovate `docker-compose`
  マネージャが `compose/check-iac.yml` の `image:` タグを既存設定の
  まま追従可能）
- Docker 起動オーバーヘッド（1 回の通し検査で数秒）を許容する

### 既存運用との関係

- `shellcheck`、`markdownlint-cli2`、`docker compose config`、
  `terraform fmt`/`validate` は引き続き使用。本ハーネスはこれらを
  置き換えない（重複しない領域のみ追加）

### 後続タスク

- TASK-033: 本決定に従い 4 ツールをリポジトリへ組込
- 将来検討（Backlog 候補）: GitHub Actions 等での CI 自動実行、
  Rego ポリシーの単体テスト（`conftest verify`）整備

## 参考

- Conftest 公式: <https://www.conftest.dev/>
- tflint: <https://github.com/terraform-linters/tflint>
- tfsec（メンテナンスモード）: <https://github.com/aquasecurity/tfsec>
- Trivy `config`: <https://trivy.dev/latest/docs/coverage/iac/terraform/>
- Hadolint: <https://github.com/hadolint/hadolint>
- Checkov: <https://www.checkov.io/>
