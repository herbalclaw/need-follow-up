# Telegram Notifier for Claude Code

Get Telegram notifications when Claude needs input, approval, or finishes tasks. **Approve or deny requests directly from Telegram!** Never come back from a break to find Claude waiting for you.

## Features

- **🔥 Two-way approval** — Approve or deny requests directly from Telegram with inline buttons
- **📱 Detailed notifications** — See exactly what Claude wants to do (commands, files, etc.)
- **⚡ Auto-starting webhook** — No manual server setup needed
- **🤖 Interactive prompts** — Get notified of "press 1 to proceed" type prompts
- **✅ Task completion** — Know when Claude finishes

## Installation

```bash
# Add the marketplace
/plugin marketplace add https://github.com/herbalclaw/need-follow-up

# Install the plugin
/plugin install telegram-notifier@lucas-plugins
```

Then restart Claude Code.

## Setup

### 1. Create a Telegram Bot

1. Message [@BotFather](https://t.me/botfather) on Telegram
2. Send `/newbot` and follow the instructions
3. Save your **bot token** (looks like `123456789:ABCdefGHIjklMNOpqrSTUvwxyz`)
4. Send `/start` to your new bot

### 2. Get Your Chat ID

1. Message [@userinfobot](https://t.me/userinfobot) on Telegram
2. It will reply with your user info including your **Chat ID** (a number like `123456789`)

### 3. Configure Environment Variables

Add to your shell profile (`.zshrc`, `.bashrc`, etc.):

```bash
export TELEGRAM_BOT_TOKEN="your-bot-token"
export TELEGRAM_CHAT_ID="your-chat-id"
```

Then restart your terminal or run `source ~/.zshrc` (or `~/.bashrc`).

**That's it!** The webhook server starts automatically when needed.

## How It Works

### Two-Way Approval from Telegram 🔥

When Claude needs permission, you get a message like this:

```
💻 Claude wants to run a command

Command:
```
npm install some-package
```

Tap a button below to approve or deny:
[✅ Approve] [❌ Deny]
```

Just tap **Approve** or **Deny** in Telegram — Claude will proceed immediately!

### Detailed Notifications

The plugin shows exactly what Claude wants to do:

| Action | Emoji | Details Shown |
|--------|-------|---------------|
| Bash command | 💻 | The actual command |
| Write file | 📝 | File path |
| Edit file | ✏️ | File path |
| Read file | 👀 | File path |
| Other | ⚠️ | Action type |

### Task Completion

```
✅ Claude finished

Your request has been completed. Check the terminal for the full response.
```

## Technical Details

### Auto-Starting Webhook Server

The plugin automatically starts a webhook server on first use. It:
- Listens for your Telegram button clicks
- Records your approve/deny decisions
- Runs in the background (no manual setup)

Server logs: `~/.claude/telegram-notifier/webhook.log`

### Timeout Behavior

If you don't respond within **5 minutes**, the request is automatically approved and you get a timeout notification.

### Hooks Used

| Hook | Purpose |
|------|---------|
| `PermissionRequest` | File edits, bash commands, etc. |
| `Notification` | Permission prompts, idle prompts, questions |
| `Stop` | Task completion |

## Troubleshooting

**Not receiving notifications?**
1. Check that `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID` are set
2. Make sure you sent `/start` to your bot on Telegram
3. Restart Claude Code after installing the plugin

**Approval buttons not working?**
1. Check that the webhook server is running: `pgrep -f webhook-server.sh`
2. Check logs: `cat ~/.claude/telegram-notifier/webhook.log`
3. The server auto-starts on the next permission request

**Want to disable completion notifications?**
```bash
export TELEGRAM_NOTIFY_COMPLETION="false"
```

## Comparison with Other Plugins

| Feature | This Plugin | agent-reachout |
|---------|-------------|----------------|
| Two-way approval | ✅ Yes | ❌ No |
| Detailed notifications | ✅ Yes | ✅ Yes |
| Auto-starting server | ✅ Yes | ❌ Manual |
| No dependencies | ✅ Yes | Requires Bun |
| Shell scripts | ✅ Yes | TypeScript |

## License

MIT
