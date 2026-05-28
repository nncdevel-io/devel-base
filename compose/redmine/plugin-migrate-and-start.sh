#!/bin/bash
# Redmine プラグインの bundle install と plugins:migrate を実行してから
# Rails server を起動するエントリースクリプト。
# 公式 redmine イメージの ENTRYPOINT が本体 DB マイグレーション完了後に
# 本スクリプトを CMD として呼び出す前提。
set -euo pipefail

cd /usr/src/redmine

# プラグインディレクトリ配下にディレクトリが存在する場合のみ処理。
# bundle install と plugins:migrate の重複実行は副作用が無いが、
# プラグイン未配置時に余計な時間をかけないため早期 return する。
plugin_dirs=(plugins/*/)
if [ ! -d "${plugin_dirs[0]}" ]; then
  echo "[entrypoint] no plugins detected; skipping plugin bootstrap"
  exec rails server -b 0.0.0.0
fi

echo "[entrypoint] installing plugin gems"
bundle install

echo "[entrypoint] running plugin migrations"
bundle exec rake redmine:plugins:migrate RAILS_ENV="${RAILS_ENV:-production}"

echo "[entrypoint] starting rails server"
exec rails server -b 0.0.0.0
