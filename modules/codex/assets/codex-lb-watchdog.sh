#!/usr/bin/env bash
set -euo pipefail

child_pid=0
startup_url="@startupUrl@"
readiness_url="@readinessUrl@"
liveness_url="@livenessUrl@"

cleanup() {
  if [ "$child_pid" -ne 0 ] && kill -0 "$child_pid" 2>/dev/null; then
    kill "$child_pid" 2>/dev/null || true
    wait "$child_pid" 2>/dev/null || true
  fi
}

request_ok() {
  local url="$1"
  @curl@ --fail --silent --show-error --max-time 3 "$url" >/dev/null
}

notify() {
  @systemdNotify@ --pid="$$" "$@" >/dev/null
}

trap cleanup INT TERM EXIT

@codexLb@ &
child_pid="$!"

startup_deadline="$((SECONDS + 70))"
until request_ok "$startup_url" && request_ok "$readiness_url"; do
  if ! kill -0 "$child_pid" 2>/dev/null; then
    wait "$child_pid"
    exit "$?"
  fi

  if [ "$SECONDS" -ge "$startup_deadline" ]; then
    echo "codex-lb did not become ready before startup deadline" >&2
    exit 1
  fi

  notify "STATUS=Waiting for codex-lb readiness: $readiness_url"
  sleep 2
done

notify READY=1 "STATUS=codex-lb is ready"

while kill -0 "$child_pid" 2>/dev/null; do
  sleep 30

  if request_ok "$liveness_url" && request_ok "$readiness_url"; then
    notify WATCHDOG=1 "STATUS=codex-lb health checks passed"
  else
    echo "codex-lb health check failed; withholding systemd watchdog ping" >&2
    notify "STATUS=codex-lb health check failed; waiting for watchdog restart"
  fi
done

wait "$child_pid"
