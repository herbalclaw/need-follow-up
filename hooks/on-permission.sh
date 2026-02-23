#!/bin/bash
# Hook for PermissionRequest events - sends Telegram notification

# Read JSON input from stdin
INPUT=$(cat)

# Extract relevant fields
REQUEST_TYPE=$(echo "$INPUT" | jq -r '.request_type // "unknown"')
MESSAGE=$(echo "$INPUT" | jq -r '.message // empty')
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')

# Load config from environment or config file
BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
CHAT_ID="${TELEGRAM_CHAT_ID:-}"

# If not in env, try to load from Claude Code config (check both paths)
if [ -z "$BOT_TOKEN" ] || [ -z "$CHAT_ID" ]; then
    # Try new path first (~/.claude/)
    CONFIG_FILE="$HOME/.claude/settings.json"
    if [ -f "$CONFIG_FILE" ]; then
        BOT_TOKEN=$(jq -r '.plugins[] | select(.name == "telegram-notifier") | .config.botToken' "$CONFIG_FILE" 2>/dev/null)
        CHAT_ID=$(jq -r '.plugins[] | select(.name == "telegram-notifier") | .config.chatId' "$CONFIG_FILE" 2>/dev/null)
    fi
    
    # Try old path as fallback
    if [ -z "$BOT_TOKEN" ] || [ -z "$CHAT_ID" ]; then
        CONFIG_FILE="$HOME/.claude-code/config.json"
        if [ -f "$CONFIG_FILE" ]; then
            BOT_TOKEN=$(jq -r '.plugins[] | select(.name == "telegram-notifier") | .config.botToken' "$CONFIG_FILE" 2>/dev/null)
            CHAT_ID=$(jq -r '.plugins[] | select(.name == "telegram-notifier") | .config.chatId' "$CONFIG_FILE" 2>/dev/null)
        fi
    fi
fi

# Check if we have credentials
if [ -z "$BOT_TOKEN" ] || [ -z "$CHAT_ID" ]; then
    echo "Telegram notifier: Missing bot token or chat ID" >&2
    exit 0
fi

# Build the notification message
NOTIFICATION="⏸️ *Claude needs input*

"

if [ -n "$MESSAGE" ]; then
    # Escape markdown characters
    ESCAPED_MESSAGE=$(echo "$MESSAGE" | sed 's/[_*[`]/\\&/g')
    NOTIFICATION="${NOTIFICATION}${ESCAPED_MESSAGE}"
else
    NOTIFICATION="${NOTIFICATION}Permission required for: ${TOOL_NAME}"
fi

# Send Telegram notification
curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
    -H "Content-Type: application/json" \
    -d "{
        \"chat_id\": \"${CHAT_ID}\",
        \"text\": \"${NOTIFICATION}\",
        \"parse_mode\": \"Markdown\"
    }" > /dev/null

# Return empty to allow the request (we just notified, didn't block)
exit 0
