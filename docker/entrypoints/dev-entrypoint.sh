#!/usr/bin/env bash
set -e

PID_FILE="/app/tmp/pids/server.pid"

if [ -f "$PID_FILE" ]; then
  echo "🧹 Removing stale PID file: $PID_FILE"
  rm -f "$PID_FILE"
fi

exec "$@"
