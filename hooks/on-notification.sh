#!/bin/bash
# Hook for Notification events - with project name

INPUT=$(cat)

NOTIF_TYPE=$(echo "$INPUT" | jq -r '.notification_type // "unknown"')
MESSAGE=$(echo "$INPUT" | jq -r '.message // ""')
TITLE=$(echo "$INPUT" | jq -r '.title // ""')

# Get project name from current directory
PROJECT_NAME=$(basename "$PWD")

# Only handle specific types
if [ "$NOTIF_TYPE" != "permission_prompt" ] && [ "$NOTIF_TYPE" != "idle_prompt" ] && [ "$NOTIF_TYPE" != "elicitation_dialog" ]; then
    exit 0
fi

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

# Build header based on notification type
case "$NOTIF_TYPE" in
    "permission_prompt") EMOJI_KEY="pause"; HEADER="Claude needs approval" ;;
    "idle_prompt") EMOJI_KEY="thinking"; HEADER="Claude is waiting" ;;
    "elicitation_dialog") EMOJI_KEY="speech"; HEADER="Claude has a question" ;;
    *) EMOJI_KEY="megaphone"; HEADER="Claude notification" ;;
esac

# Trim message
TRIMMED_MSG=""
if [ -n "$MESSAGE" ]; then
    TRIMMED_MSG=$(echo "$MESSAGE" | head -c 500)
    [ ${#MESSAGE} -gt 500 ] && TRIMMED_MSG="${TRIMMED_MSG}..."
fi

# Send via Python for proper Unicode/emoji support
python -c "
import urllib.request, json, sys
emojis = {'pause':'\u23F8\uFE0F','thinking':'\U0001F914','speech':'\U0001F4AC','megaphone':'\U0001F4E2','folder':'\U0001F4C1'}
e = emojis.get(sys.argv[1], '\U0001F4E2')
msg = f\"{emojis['folder']} {sys.argv[2]}\n\n{e} {sys.argv[3]}\"
if sys.argv[4]: msg += f\"\n\n{sys.argv[4]}\"
if sys.argv[5]: msg += f\"\n\n{sys.argv[5]}\"
msg += '\n\nCheck terminal to respond'
url = 'https://api.telegram.org/bot' + sys.argv[6] + '/sendMessage'
data = json.dumps({'chat_id': sys.argv[7], 'text': msg}).encode()
req = urllib.request.Request(url, data=data, headers={'Content-Type': 'application/json'})
try: urllib.request.urlopen(req, timeout=5)
except: pass
" "$EMOJI_KEY" "$PROJECT_NAME" "$HEADER" "$TITLE" "$TRIMMED_MSG" "$BOT_TOKEN" "$CHAT_ID"

exit 0
