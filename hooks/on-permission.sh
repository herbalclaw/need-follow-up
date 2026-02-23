#!/bin/bash
# Hook for PermissionRequest events - Notification only with project name (no emojis for compatibility)

INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // "unknown"')
TOOL_INPUT=$(echo "$INPUT" | jq -r '.tool_input // {}')
FILE_PATH=$(echo "$TOOL_INPUT" | jq -r '.file_path // .path // ""')
COMMAND=$(echo "$TOOL_INPUT" | jq -r '.command // ""')

# Get project name from current directory
PROJECT_NAME=$(basename "$PWD")

BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
CHAT_ID="${TELEGRAM_CHAT_ID:-}"

if [ -z "$BOT_TOKEN" ] || [ -z "$CHAT_ID" ]; then
    for CONFIG_FILE in "$HOME/.claude/settings.json" "$HOME/.claude-code/config.json"; do
        if [ -f "$CONFIG_FILE" ]; then
            BOT_TOKEN=$(jq -r '.plugins[]? | select(.name == "telegram-notifier") | .config.botToken' "$CONFIG_FILE" 2>/dev/null)
            CHAT_ID=$(jq -r '.plugins[]? | select(.name == "telegram-notifier") | .config.chatId' "$CONFIG_FILE" 2>/dev/null)
            [ -n "$BOT_TOKEN" ] && [ -n "$CHAT_ID" ] && break
        fi
    done
fi

[ -z "$BOT_TOKEN" ] && exit 0

# Build message (no emojis for cross-platform compatibility)
case "$TOOL_NAME" in
    "Bash")
        HEADER="Claude wants to run a command"
        DETAIL="${COMMAND:0:300}"
        [ ${#COMMAND} -gt 300 ] && DETAIL="${DETAIL}..."
        ;;
    "Write")
        HEADER="Claude wants to create a file"
        DETAIL="${FILE_PATH}"
        ;;
    "Edit")
        HEADER="Claude wants to edit a file"
        DETAIL="${FILE_PATH}"
        ;;
    "Read")
        HEADER="Claude wants to read a file"
        DETAIL="${FILE_PATH}"
        ;;
    *)
        HEADER="Claude needs permission"
        DETAIL="${TOOL_NAME}"
        [ -n "$FILE_PATH" ] && DETAIL="${DETAIL}: ${FILE_PATH}"
        ;;
esac

NOTIFICATION="Project: ${PROJECT_NAME}

${HEADER}

${DETAIL}

Go to terminal to approve"

# Send notification (no parse_mode to avoid markdown issues)
curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
    -H "Content-Type: application/json" \
    -d "{
        \"chat_id\": \"${CHAT_ID}\",
        \"text\": \"${NOTIFICATION}\"
    }" > /dev/null

exit 0
