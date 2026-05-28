ARG REDMINE_VERSION=5.1.4
FROM redmine:${REDMINE_VERSION}

COPY plugin-migrate-and-start.sh /usr/local/bin/plugin-migrate-and-start.sh
RUN chmod +x /usr/local/bin/plugin-migrate-and-start.sh

# 公式 ENTRYPOINT（/docker-entrypoint.sh）はそのまま利用し、
# 本体 DB マイグレーション後に走る CMD をプラグイン処理付きに差し替える
CMD ["/usr/local/bin/plugin-migrate-and-start.sh"]
