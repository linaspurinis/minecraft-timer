#!/bin/zsh
source minertimer.config

echo "Fetching latest update..."
UPDATES=$(curl -s "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/getUpdates?limit=1")

echo "=== RAW RESPONSE ==="
echo "$UPDATES"
echo ""
echo "=== GREP FOR callback_data ==="
echo "$UPDATES" | grep callback_data
echo ""
echo "=== EXTRACT callback_data ==="
echo "$UPDATES" | grep -o '"callback_data":"[^"]*"'
echo ""
echo "=== CUT ==="
echo "$UPDATES" | grep -o '"callback_data":"[^"]*"' | cut -d'"' -f4
