#!/bin/bash
# Hook for Stop events - notifies when Claude finishes responding

# Read JSON input from stdin
INPUT=$(cat)

# Load config
BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
CHAT_ID="${TELEGRAM_CHAT_ID:-}"

if [ -z "$BOT_TOKEN" ] || [ -z "$CHAT_ID" ]; then
    CONFIG_FILE="$HOME/.claude-code/config.json"
    if [ -f "$CONFIG_FILE" ]; then
        BOT_TOKEN=$(jq -r '.plugins[] | select(.name == "telegram-notifier") | .config.botToken' "$CONFIG_FILE" 2>/dev/null)
        CHAT_ID=$(jq -r '.plugins[] | select(.name == "telegram-notifier") | .config.chatId' "$CONFIG_FILE" 2>/dev/null)
    fi
fi

if [ -z "$BOT_TOKEN" ] || [ -z "$CHAT_ID" ]; then
    exit 0
fi

# Check if user wants completion notifications
NOTIFY_COMPLETION="${TELEGRAM_NOTIFY_COMPLETION:-true}"
if [ "$NOTIFY_COMPLETION" = "false" ]; then
    exit 0
fi

# Send completion notification
NOTIFICATION="✅ *Claude finished*

Your request has been completed. Check the terminal for the full response."

curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
    -H "Content-Type: application/json" \
    -d "{
        \"chat_id\": \"${CHAT_ID}\",
        \"text\": \"${NOTIFICATION}\",
        \"parse_mode\": \"Markdown\"
    }" > /dev/null

exit 0
