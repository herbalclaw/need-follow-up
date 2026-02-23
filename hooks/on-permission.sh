#!/bin/bash
# Hook for PermissionRequest events - Cross-platform (WSL, macOS, Linux)

# Read JSON input from stdin
INPUT=$(cat)

# Extract fields
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // "unknown"')
TOOL_INPUT=$(echo "$INPUT" | jq -r '.tool_input // {}')
REQUEST_ID=$(echo "$INPUT" | jq -r '.request_id // "unknown"')
DESCRIPTION=$(echo "$INPUT" | jq -r '.description // ""')
FILE_PATH=$(echo "$TOOL_INPUT" | jq -r '.file_path // .path // ""')
COMMAND=$(echo "$TOOL_INPUT" | jq -r '.command // ""')

# Load config from environment or settings
BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
CHAT_ID="${TELEGRAM_CHAT_ID:-}"

if [ -z "$BOT_TOKEN" ] || [ -z "$CHAT_ID" ]; then
    # Try settings.json
    for CONFIG_FILE in "$HOME/.claude/settings.json" "$HOME/.claude-code/config.json"; do
        if [ -f "$CONFIG_FILE" ]; then
            BOT_TOKEN=$(jq -r '.plugins[]? | select(.name == "telegram-notifier") | .config.botToken' "$CONFIG_FILE" 2>/dev/null)
            CHAT_ID=$(jq -r '.plugins[]? | select(.name == "telegram-notifier") | .config.chatId' "$CONFIG_FILE" 2>/dev/null)
            [ -n "$BOT_TOKEN" ] && [ -n "$CHAT_ID" ] && break
        fi
    done
fi

# Exit if no config
if [ -z "$BOT_TOKEN" ] || [ -z "$CHAT_ID" ]; then
    exit 0
fi

# Setup paths
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WEBHOOK_SCRIPT="${SCRIPT_DIR}/webhook-server.sh"
PENDING_DIR="${HOME}/.claude/telegram-notifier"
PID_FILE="${PENDING_DIR}/webhook.pid"

mkdir -p "$PENDING_DIR"

# Cross-platform server check and start
start_server() {
    if [ -x "$WEBHOOK_SCRIPT" ]; then
        # Start in background, detached from terminal
        ( "$WEBHOOK_SCRIPT" > "${PENDING_DIR}/webhook.log" 2>&1 ) &
        sleep 2
    fi
}

# Check if server is running
NEED_START=false
if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE" 2>/dev/null)
    if [ -n "$OLD_PID" ]; then
        # Cross-platform process check
        if ! kill -0 "$OLD_PID" 2>/dev/null; then
            NEED_START=true
        fi
    else
        NEED_START=true
    fi
else
    NEED_START=true
fi

# Start if needed
if [ "$NEED_START" = true ]; then
    rm -f "$PID_FILE"
    start_server
fi

# Build notification message
case "$TOOL_NAME" in
    "Bash")
        EMOJI="💻"
        HEADER="Claude wants to run a command"
        if [ -n "$COMMAND" ]; then
            DETAIL="Command:\\n\`\`\`\\n${COMMAND:0:200}\\n\`\`\`"
            [ ${#COMMAND} -gt 200 ] && DETAIL="${DETAIL}..."
        else
            DETAIL="Command: (see terminal)"
        fi
        ;;
    "Write")
        EMOJI="📝"
        HEADER="Claude wants to create a file"
        DETAIL="📄 \`${FILE_PATH}\`"
        ;;
    "Edit")
        EMOJI="✏️"
        HEADER="Claude wants to edit a file"
        DETAIL="📄 \`${FILE_PATH}\`"
        ;;
    "Read")
        EMOJI="👀"
        HEADER="Claude wants to read a file"
        DETAIL="📄 \`${FILE_PATH}\`"
        ;;
    *)
        EMOJI="⚠️"
        HEADER="Claude needs permission"
        DETAIL="Action: ${TOOL_NAME}"
        [ -n "$FILE_PATH" ] && DETAIL="${DETAIL}\\n📄 \`${FILE_PATH}\`"
        ;;
esac

[ -n "$DESCRIPTION" ] && DETAIL="${DETAIL}\\n\\n📝 ${DESCRIPTION}"

NOTIFICATION="${EMOJI} *${HEADER}*

${DETAIL}

_Tap a button:_"

# Escape for JSON
ESCAPED=$(printf '%s' "$NOTIFICATION" | sed 's/"/\\"/g' | tr '\n' ' ' | sed 's/  */ /g')

# Send notification with buttons
RESPONSE=$(curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
    -H "Content-Type: application/json" \
    -d "{
        \"chat_id\": \"${CHAT_ID}\",
        \"text\": \"${ESCAPED}\",
        \"parse_mode\": \"Markdown\",
        \"reply_markup\": {
            \"inline_keyboard\": [
                [
                    {\"text\": \"✅ Approve\", \"callback_data\": \"approve:${REQUEST_ID}\"},
                    {\"text\": \"❌ Deny\", \"callback_data\": \"deny:${REQUEST_ID}\"}
                ]
            ]
        }
    }")

# Check if sent successfully
if [ "$(echo "$RESPONSE" | jq -r '.ok')" != "true" ]; then
    exit 0
fi

# Wait for user decision
DECISION_FILE="${PENDING_DIR}/${REQUEST_ID}.decision"
TIMEOUT=300  # 5 minutes
ELAPSED=0

while [ $ELAPSED -lt $TIMEOUT ]; do
    if [ -f "$DECISION_FILE" ]; then
        DECISION=$(cat "$DECISION_FILE" 2>/dev/null)
        rm -f "$DECISION_FILE"
        if [ "$DECISION" = "approve" ]; then
            exit 0
        else
            echo "Request denied by user via Telegram" >&2
            exit 1
        fi
    fi
    sleep 2
    ELAPSED=$((ELAPSED + 2))
done

# Timeout - notify and proceed
curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
    -H "Content-Type: application/json" \
    -d "{
        \"chat_id\": \"${CHAT_ID}\",
        \"text\": \"⏰ Approval timed out - proceeding\",
        \"parse_mode\": \"Markdown\"
    }" > /dev/null

exit 0
