#!/bin/bash
# Hook for Stop events - with project name

INPUT=$(cat)

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

[ "${TELEGRAM_NOTIFY_COMPLETION:-true}" = "false" ] && exit 0

# Send via Python for proper Unicode/emoji support
python -c "
import urllib.request, json, sys
msg = f\"\U0001F4C1 {sys.argv[1]}\n\n\u2705 Claude finished\n\nYour request has been completed. Check the terminal for details.\"
url = 'https://api.telegram.org/bot' + sys.argv[2] + '/sendMessage'
data = json.dumps({'chat_id': sys.argv[3], 'text': msg}).encode()
req = urllib.request.Request(url, data=data, headers={'Content-Type': 'application/json'})
try: urllib.request.urlopen(req, timeout=5)
except: pass
" "$PROJECT_NAME" "$BOT_TOKEN" "$CHAT_ID"

exit 0
