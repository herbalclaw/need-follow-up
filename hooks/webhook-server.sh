#!/bin/bash
# Webhook receiver for Telegram callbacks - Cross-platform (WSL, macOS, Linux)

BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
CHAT_ID="${TELEGRAM_CHAT_ID:-}"

if [ -z "$BOT_TOKEN" ] || [ -z "$CHAT_ID" ]; then
    echo "Missing TELEGRAM_BOT_TOKEN or TELEGRAM_CHAT_ID"
    exit 1
fi

# Setup directories
PENDING_DIR="${HOME}/.claude/telegram-notifier"
mkdir -p "$PENDING_DIR"

# PID file for cross-platform process tracking
PID_FILE="${PENDING_DIR}/webhook.pid"

# Check if already running (cross-platform)
if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE" 2>/dev/null)
    if [ -n "$OLD_PID" ]; then
        # Check if process exists (works on macOS, Linux, WSL)
        if kill -0 "$OLD_PID" 2>/dev/null; then
            echo "Webhook server already running (PID: $OLD_PID)"
            exit 0
        fi
    fi
fi

# Save current PID
echo $$ > "$PID_FILE"

# Cleanup function
cleanup() {
    rm -f "$PID_FILE"
    exit 0
}
trap cleanup EXIT INT TERM

# Offset for Telegram updates
OFFSET=0

# Main loop
while true; do
    # Get updates from Telegram
    UPDATES=$(curl -s "https://api.telegram.org/bot${BOT_TOKEN}/getUpdates?offset=${OFFSET}&limit=10")
    
    # Check if response is valid
    if [ "$(echo "$UPDATES" | jq -r '.ok')" != "true" ]; then
        sleep 2
        continue
    fi
    
    # Process each update
    RESULT_COUNT=$(echo "$UPDATES" | jq '.result | length')
    
    if [ "$RESULT_COUNT" -gt 0 ]; then
        echo "$UPDATES" | jq -c '.result[]' | while read -r UPDATE; do
            UPDATE_ID=$(echo "$UPDATE" | jq -r '.update_id')
            OFFSET=$((UPDATE_ID + 1))
            
            # Check for callback query (inline button click)
            CALLBACK=$(echo "$UPDATE" | jq -r '.callback_query // empty')
            
            if [ -n "$CALLBACK" ] && [ "$CALLBACK" != "null" ]; then
                CALLBACK_ID=$(echo "$CALLBACK" | jq -r '.id')
                CALLBACK_DATA=$(echo "$CALLBACK" | jq -r '.data')
                
                # Parse action and request ID
                ACTION=$(echo "$CALLBACK_DATA" | cut -d':' -f1)
                REQUEST_ID=$(echo "$CALLBACK_DATA" | cut -d':' -f2)
                
                if [ "$ACTION" = "approve" ] || [ "$ACTION" = "deny" ]; then
                    # Store the decision
                    echo "$ACTION" > "${PENDING_DIR}/${REQUEST_ID}.decision"
                    
                    # Answer callback to remove loading spinner
                    curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/answerCallbackQuery" \
                        -H "Content-Type: application/json" \
                        -d "{\"callback_query_id\": \"${CALLBACK_ID}\", \"text\": \"${ACTION} recorded\"}" > /dev/null
                    
                    # Update the message
                    MSG_ID=$(echo "$CALLBACK" | jq -r '.message.message_id')
                    CHAT_ID_MSG=$(echo "$CALLBACK" | jq -r '.message.chat.id')
                    
                    if [ "$ACTION" = "approve" ]; then
                        NEW_TEXT="✅ *Approved*\n\nThis action has been approved."
                    else
                        NEW_TEXT="❌ *Denied*\n\nThis action has been denied."
                    fi
                    
                    curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/editMessageText" \
                        -H "Content-Type: application/json" \
                        -d "{
                            \"chat_id\": ${CHAT_ID_MSG},
                            \"message_id\": ${MSG_ID},
                            \"text\": \"${NEW_TEXT}\",
                            \"parse_mode\": \"Markdown\"
                        }" > /dev/null
                fi
            fi
        done
    fi
    
    sleep 1
done
