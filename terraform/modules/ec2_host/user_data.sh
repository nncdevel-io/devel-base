#!/usr/bin/env bash
# Amazon Linux 2023 EC2 ホストの初期化スクリプト。
# TASK-008 の成果物。要件書 3.6（OS チューニング）と 9.4
# （Docker Engine・Compose のブートストラップ）を実装する。
#
# 適用範囲:
#   - dnf による Docker Engine の導入
#   - Compose v2 プラグインのバイナリ配置（GitHub Releases）
#   - sysctl: inotify、vm.max_map_count（SonarQube 内 Elasticsearch 要件）
#   - limits.conf: nofile（多数のソケット使用）
#   - Docker daemon: json-file logging driver（10m × 3）
#   - ec2-user の docker グループ追加
#
# 適用範囲外（別タスクで担当）:
#   - SSM Session Manager 有効化（AL2023 は SSM Agent プリインストール、
#     IAM Role 付与のみで動作。TASK-005 / TASK-009）
#   - IMDSv2 強制（インスタンスメタデータオプションで指定。TASK-009）
#   - docker-compose.yml の配布（運用手順 / Systems Manager。TASK-029）

set -euxo pipefail
exec > >(tee -a /var/log/devel-base-user-data.log) 2>&1

echo "[bootstrap] start at $(date -Iseconds)"

# ---- OS チューニング（要件書 3.6） ----
cat > /etc/sysctl.d/99-devel-base.conf <<'SYSCTL'
fs.inotify.max_user_watches = 524288
fs.inotify.max_user_instances = 8192
vm.max_map_count = 262144
SYSCTL
sysctl --system

cat > /etc/security/limits.d/99-devel-base.conf <<'LIMITS'
*  soft  nofile  65536
*  hard  nofile  65536
LIMITS

# systemd 配下のサービスは limits.conf を読まないため、明示設定
mkdir -p /etc/systemd/system.conf.d
cat > /etc/systemd/system.conf.d/99-devel-base.conf <<'SYSTEMD'
[Manager]
DefaultLimitNOFILE=65536
SYSTEMD

# ---- Docker Engine ----
dnf install -y docker
systemctl enable docker

# Docker daemon 設定（ログ無限肥大の防止）
mkdir -p /etc/docker
cat > /etc/docker/daemon.json <<'DOCKER'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
DOCKER

# ---- Compose v2 plugin ----
# renovate: datasource=github-releases depName=docker/compose
COMPOSE_VERSION="v2.32.4"
COMPOSE_PLUGIN_DIR="/usr/local/lib/docker/cli-plugins"
mkdir -p "${COMPOSE_PLUGIN_DIR}"
curl -fsSL -o "${COMPOSE_PLUGIN_DIR}/docker-compose" \
  "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s | tr '[:upper:]' '[:lower:]')-$(uname -m)"
chmod +x "${COMPOSE_PLUGIN_DIR}/docker-compose"

# ---- 設定反映・起動 ----
systemctl daemon-reload
systemctl restart docker

# Session Manager 経由のオペレーションでも sudo なしで docker を使える
usermod -aG docker ec2-user || true

# ---- 動作確認 ----
docker --version
docker compose version

echo "[bootstrap] complete at $(date -Iseconds)"
