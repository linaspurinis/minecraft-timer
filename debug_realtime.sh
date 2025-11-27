#!/bin/zsh
source minertimer.config

echo "Waiting for button click... (press Ctrl+C to stop)"
echo ""

OFFSET=0

while true; do
    UPDATES=$(curl -s "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/getUpdates?offset=${OFFSET}&timeout=10")

    if echo "$UPDATES" | grep -q "callback_query"; then
        echo "=== GOT CALLBACK! ==="
        echo "$UPDATES" | head -c 500
        echo ""
        echo "=== TRYING TO EXTRACT ==="
        echo "Pattern 1: grep -o '\"callback_data\":\"[^\"]*\"'"
        echo "$UPDATES" | grep -o '"callback_data":"[^"]*"'
        echo ""
        echo "Pattern 2: grep callback_data"
        echo "$UPDATES" | grep callback_data | head -c 200
        echo ""
        break
    fi

    # Update offset
    NEW_ID=$(echo "$UPDATES" | grep -o '"update_id":[0-9]*' | head -1 | cut -d':' -f2)
    if [ -n "$NEW_ID" ]; then
        OFFSET=$((NEW_ID + 1))
    fi

    echo -n "."
    sleep 1
done
