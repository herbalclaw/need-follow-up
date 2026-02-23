#!/bin/bash
# Start the webhook server for two-way Telegram approval (silent version for auto-start)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WEBHOOK="${SCRIPT_DIR}/webhook-server.sh"
PENDING_DIR="${HOME}/.claude/telegram-notifier"
PID_FILE="${PENDING_DIR}/webhook.pid"

mkdir -p "$PENDING_DIR"

# Check if already running
if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE" 2>/dev/null)
    if [ -n "$OLD_PID" ] && kill -0 "$OLD_PID" 2>/dev/null; then
        exit 0  # Already running, exit silently
    fi
fi

# Start server silently
if [ -x "$WEBHOOK" ]; then
    nohup "$WEBHOOK" > "${PENDING_DIR}/webhook.log" 2>&1 &
fi

exit 0
