#!/usr/bin/env bash
set -e

PID_FILE="/app/tmp/pids/server.pid"

is_truthy() {
  case "${1:-}" in
    1|true|TRUE|True|yes|YES|y|Y|on|ON) return 0 ;;
    *) return 1 ;;
  esac
}

if [ -f "$PID_FILE" ]; then
  echo "Removing stale PID file: $PID_FILE"
  rm -f "$PID_FILE"
fi

bundle install

if is_truthy "${DB_RESET:-}"; then
  echo "[DB_RESET] Dropping and recreating database..."
  bin/rails db:drop db:create db:migrate
else
  bin/rails db:prepare
fi

bin/rails db:seed

exec "$@"
