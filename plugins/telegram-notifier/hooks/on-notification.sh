#!/bin/bash
# Hook for Notification events - handles idle prompts, permission prompts, etc.

# Read JSON input from stdin
INPUT=$(cat)

# Extract notification type and message
NOTIF_TYPE=$(echo "$INPUT" | jq -r '.notification_type // "unknown"')
MESSAGE=$(echo "$INPUT" | jq -r '.message // empty')

# Only handle specific notification types
if [ "$NOTIF_TYPE" != "permission_prompt" ] && [ "$NOTIF_TYPE" != "idle_prompt" ] && [ "$NOTIF_TYPE" != "elicitation_dialog" ]; then
    exit 0
fi

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

# Build emoji based on type
case "$NOTIF_TYPE" in
    "permission_prompt")
        EMOJI="⏸️"
        HEADER="Claude needs approval"
        ;;
    "idle_prompt")
        EMOJI="🤔"
        HEADER="Claude is waiting"
        ;;
    "elicitation_dialog")
        EMOJI="💬"
        HEADER="Claude has a question"
        ;;
    *)
        EMOJI="📢"
        HEADER="Claude notification"
        ;;
esac

# Build message
NOTIFICATION="${EMOJI} *${HEADER}*

"

if [ -n "$MESSAGE" ]; then
    ESCAPED_MESSAGE=$(echo "$MESSAGE" | sed 's/[_*[`]/\\&/g')
    NOTIFICATION="${NOTIFICATION}${ESCAPED_MESSAGE}"
fi

# Send notification
curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
    -H "Content-Type: application/json" \
    -d "{
        \"chat_id\": \"${CHAT_ID}\",
        \"text\": \"${NOTIFICATION}\",
        \"parse_mode\": \"Markdown\"
    }" > /dev/null

exit 0
