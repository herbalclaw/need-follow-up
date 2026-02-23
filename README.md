# Telegram Notifier for Claude Code

Get Telegram notifications when Claude needs input, approval, or finishes tasks. Never come back from a break to find Claude waiting for you to press "1" or type "yes"!

## What It Handles

- **Permission requests** — File edits, bash commands, etc.
- **Interactive prompts** — "Press 1 to proceed", "Enter your choice", etc.
- **Questions** — When Claude needs clarification
- **Idle prompts** — When Claude is waiting for you
- **Task completion** — When Claude finishes responding

## Installation

```bash
# Add the marketplace
/plugin marketplace add https://github.com/herbalclaw/need-follow-up

# Install the plugin
/plugin install telegram-notifier@lucas-plugins
```

## Setup

### 1. Create a Telegram Bot

1. Message [@BotFather](https://t.me/botfather) on Telegram
2. Send `/newbot` and follow the instructions
3. Save your **bot token** (looks like `123456789:ABCdefGHIjklMNOpqrSTUvwxyz`)
4. Send `/start` to your new bot

### 2. Get Your Chat ID

1. Message [@userinfobot](https://t.me/userinfobot) on Telegram
2. It will reply with your user info including your **Chat ID** (a number like `123456789`)

### 3. Configure the Plugin

Add to your `~/.claude-code/config.json`:

```json
{
  "plugins": [
    {
      "name": "telegram-notifier",
      "config": {
        "botToken": "YOUR_BOT_TOKEN",
        "chatId": "YOUR_CHAT_ID"
      }
    }
  ]
}
```

Or use environment variables (quickest for testing):

```bash
export TELEGRAM_BOT_TOKEN="your-bot-token"
export TELEGRAM_CHAT_ID="your-chat-id"
export TELEGRAM_NOTIFY_COMPLETION="true"  # optional
```

Then restart Claude Code.

## Notifications You'll Receive

**Permission Required:**
```
⏸️ Claude needs approval

Claude wants to edit src/config.ts
Allow this edit?
```

**Interactive Prompt (e.g., "press 1 to proceed"):**
```
💬 Claude has a question

Multiple options available:
1. Proceed with option A
2. Proceed with option B
3. Cancel

Enter your choice:
```

**Idle/Waiting:**
```
🤔 Claude is waiting

Waiting for your input to continue...
```

**Task Complete:**
```
✅ Claude finished

Your request has been completed. Check the terminal for the full response.
```

## How It Works

The plugin uses Claude Code's native hook system:

| Hook | When It Fires |
|------|---------------|
| `PermissionRequest` | Before file edits, bash commands, etc. |
| `Notification` | Permission prompts, idle prompts, questions |
| `Stop` | When Claude finishes responding |

Each hook sends a Telegram message so you know when to come back to your terminal.

## Troubleshooting

**Not receiving notifications?**
1. Check that `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID` are set
2. Make sure you sent `/start` to your bot on Telegram
3. Restart Claude Code after installing the plugin
4. Check Claude Code's logs for hook errors

**Want to disable completion notifications?**
```bash
export TELEGRAM_NOTIFY_COMPLETION="false"
```

## License

MIT
