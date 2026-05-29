#!/usr/bin/env bash
# devel-base クリーンインストールスクリプト
#
# 既存コンテナ・ビルドキャッシュ・カスタムイメージを破棄してから
# pull → build → up を実行する。containerd の partial layer 破損
# （`failed precondition`）から復旧する用途も兼ねる。
#
# データボリュームはデフォルトで保持する。完全な初期化が必要な
# 場合のみ PURGE_VOLUMES=1 を指定する（DB・添付ファイル等が消える）。
#
# 前提:
#   - Docker / Docker Compose v2 がインストール済
#   - compose/.env が compose/.env.example を元に作成済
#   - Docker Desktop (macOS/Windows) を使う場合はプロキシ設定が
#     現環境で到達可能であること（Settings → Resources → Proxies）
#
# 使い方:
#   ./scripts/install.sh                         # 標準クリーンインストール
#   DEEP_CLEAN=1     ./scripts/install.sh        # docker system prune -af も実行
#   PURGE_VOLUMES=1  ./scripts/install.sh        # 既存データボリュームも削除
#   SKIP_PULL=1      ./scripts/install.sh        # 公式イメージの pull をスキップ
#   SKIP_UP=1        ./scripts/install.sh        # 起動せず pull + build まで

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
COMPOSE_DIR="${REPO_ROOT}/compose"
COMPOSE_FILE="${COMPOSE_DIR}/docker-compose.yml"
PROJECT_NAME="devel-base"
CUSTOM_IMAGE="${PROJECT_NAME}/redmine"

DC=(docker compose -f "${COMPOSE_FILE}")

# ---- 事前チェック ----
if ! command -v docker >/dev/null 2>&1; then
  echo "[install] ERROR: docker コマンドが見つかりません" >&2
  exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
  echo "[install] ERROR: docker compose v2 が利用できません" >&2
  exit 1
fi

if [ ! -f "${COMPOSE_DIR}/.env" ]; then
  echo "[install] ERROR: ${COMPOSE_DIR}/.env が存在しません" >&2
  echo "[install]        cp ${COMPOSE_DIR}/.env.example ${COMPOSE_DIR}/.env" >&2
  echo "[install]        として作成し、値を設定してから再実行してください" >&2
  exit 1
fi

echo "[install] compose file: ${COMPOSE_FILE}"

# ---- 構文検証 ----
echo "[install] docker compose config で構文検証"
"${DC[@]}" config --quiet

# ---- クリーンアップ ----
if [ "${PURGE_VOLUMES:-0}" = "1" ]; then
  echo "[install] WARN: PURGE_VOLUMES=1 — データボリュームも削除します"
  echo "[install]       GitLab / Jenkins / Redmine / SonarQube / PostgreSQL のデータが消失します"
  echo -n "[install]       5 秒以内に Ctrl-C で中断してください..."
  sleep 5
  echo " 続行"
  "${DC[@]}" down --volumes --remove-orphans || true
else
  echo "[install] 既存コンテナを停止・削除（ボリュームは保持）"
  "${DC[@]}" down --remove-orphans || true
fi

echo "[install] カスタムイメージ ${CUSTOM_IMAGE} を削除"
# タグ違いも含めて掃除（5.1.4 以外が残っている可能性）
docker images --format '{{.Repository}}:{{.Tag}}' \
  | grep -E "^${CUSTOM_IMAGE}:" \
  | xargs -r docker image rm -f \
  || true

echo "[install] BuildKit / builder キャッシュを削除"
docker builder prune -af >/dev/null

if [ "${DEEP_CLEAN:-0}" = "1" ]; then
  echo "[install] DEEP_CLEAN=1 — docker system prune -af を実行"
  echo "[install] WARN: このマシン上の未使用イメージ全てが削除されます（他プロジェクト含む）"
  docker system prune -af >/dev/null
else
  echo "[install] dangling リソースを掃除（未使用 image は保持）"
  docker system prune -f >/dev/null
fi

# ---- 公式イメージ pull（build 対象は除外） ----
if [ "${SKIP_PULL:-0}" != "1" ]; then
  echo "[install] 公式イメージを pull（buildable サービスは除外）"
  "${DC[@]}" pull --ignore-buildable
else
  echo "[install] SKIP_PULL=1 のため pull をスキップ"
fi

# ---- Redmine カスタムイメージ build（キャッシュなし） ----
echo "[install] Redmine カスタムイメージを build（--no-cache）"
"${DC[@]}" build --no-cache redmine

# ---- 起動 ----
if [ "${SKIP_UP:-0}" != "1" ]; then
  echo "[install] サービスを起動（detached）"
  "${DC[@]}" up -d

  if [ -x "${SCRIPT_DIR}/healthcheck.sh" ]; then
    echo "[install] healthcheck.sh を実行"
    "${SCRIPT_DIR}/healthcheck.sh" || {
      echo "[install] WARN: healthcheck に失敗しました（初回起動は時間がかかる場合があります）" >&2
    }
  else
    echo "[install] healthcheck.sh が未作成のためスキップ"
  fi
else
  echo "[install] SKIP_UP=1 のため起動をスキップ"
fi

echo "[install] 完了"
