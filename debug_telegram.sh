#!/bin/zsh

###
# DEBUG SCRIPT - Check Telegram bot updates and webhook status
###

echo "=========================================="
echo "TELEGRAM BOT DEBUG"
echo "=========================================="
echo ""

# Load configuration
if [ -f "minertimer.config" ]; then
    source minertimer.config
else
    echo "❌ minertimer.config not found!"
    exit 1
fi

if [ -z "$TELEGRAM_BOT_TOKEN" ] || [ -z "$TELEGRAM_CHAT_ID" ]; then
    echo "❌ Telegram not configured"
    exit 1
fi

echo "Bot Token: ${TELEGRAM_BOT_TOKEN:0:20}..."
echo "Chat ID: $TELEGRAM_CHAT_ID"
echo ""

# Check webhook status
echo "📡 Checking webhook status..."
WEBHOOK_INFO=$(curl -s "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/getWebhookInfo")
echo "$WEBHOOK_INFO" | python3 -m json.tool 2>/dev/null || echo "$WEBHOOK_INFO"
echo ""

# Get recent updates
echo "📨 Getting recent updates (last 5)..."
UPDATES=$(curl -s "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/getUpdates?limit=5")
echo "$UPDATES" | python3 -m json.tool 2>/dev/null || echo "$UPDATES"
echo ""

echo "=========================================="
echo "DEBUG COMPLETE"
echo "=========================================="
