#!/bin/bash
# Hook for PermissionRequest events - Notification only with project name

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

# Build header based on tool
case "$TOOL_NAME" in
    "Bash") EMOJI_KEY="computer"; HEADER="Claude wants to run a command" ;;
    "Write") EMOJI_KEY="memo"; HEADER="Claude wants to create a file" ;;
    "Edit") EMOJI_KEY="pencil"; HEADER="Claude wants to edit a file" ;;
    "Read") EMOJI_KEY="eyes"; HEADER="Claude wants to read a file" ;;
    *) EMOJI_KEY="warning"; HEADER="Claude needs permission" ;;
esac

# Build detail
case "$TOOL_NAME" in
    "Bash")
        DETAIL="${COMMAND:0:300}"
        [ ${#COMMAND} -gt 300 ] && DETAIL="${DETAIL}..."
        ;;
    *)
        DETAIL="${FILE_PATH}"
        ;;
esac

# Send via Python for proper Unicode/emoji support
python -c "
import urllib.request, json, sys
emojis = {'computer':'\U0001F4BB','memo':'\U0001F4DD','pencil':'\u270F\uFE0F','eyes':'\U0001F440','warning':'\u26A0\uFE0F','folder':'\U0001F4C1','clock':'\u23F0'}
e = emojis.get(sys.argv[1], '\u26A0\uFE0F')
msg = f\"{emojis['folder']} {sys.argv[2]}\n\n{e} {sys.argv[3]}\n\n{sys.argv[4]}\n\n{emojis['clock']} Go to terminal to approve\"
url = 'https://api.telegram.org/bot' + sys.argv[5] + '/sendMessage'
data = json.dumps({'chat_id': sys.argv[6], 'text': msg}).encode()
req = urllib.request.Request(url, data=data, headers={'Content-Type': 'application/json'})
try: urllib.request.urlopen(req, timeout=5)
except: pass
" "$EMOJI_KEY" "$PROJECT_NAME" "$HEADER" "$DETAIL" "$BOT_TOKEN" "$CHAT_ID"

exit 0
