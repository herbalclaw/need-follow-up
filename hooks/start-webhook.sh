#!/bin/bash
# Start the webhook server for two-way Telegram approval

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WEBHOOK="${SCRIPT_DIR}/webhook-server.sh"
PENDING_DIR="${HOME}/.claude/telegram-notifier"
PID_FILE="${PENDING_DIR}/webhook.pid"
LOG_FILE="${PENDING_DIR}/webhook.log"

mkdir -p "$PENDING_DIR"

# Check if already running
if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE" 2>/dev/null)
    if [ -n "$OLD_PID" ] && kill -0 "$OLD_PID" 2>/dev/null; then
        echo "[telegram-notifier] Webhook server already running (PID: $OLD_PID)" >&2
        exit 0
    fi
fi

# Start server
if [ -x "$WEBHOOK" ]; then
    echo "[telegram-notifier] Starting webhook server..." >&2
    nohup "$WEBHOOK" > "$LOG_FILE" 2>&1 &
    sleep 2
    
    # Check if it started
    if [ -f "$PID_FILE" ]; then
        NEW_PID=$(cat "$PID_FILE")
        if kill -0 "$NEW_PID" 2>/dev/null; then
            echo "[telegram-notifier] Webhook server started (PID: $NEW_PID)" >&2
        else
            echo "[telegram-notifier] Failed to start webhook server" >&2
        fi
    fi
else
    echo "[telegram-notifier] Webhook script not found: $WEBHOOK" >&2
fi

exit 0
