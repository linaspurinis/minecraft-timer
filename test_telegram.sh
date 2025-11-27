#!/bin/zsh

###
# TEST SCRIPT - Tests the Telegram authentication flow
# This simulates what your kid will see when the time limit is reached
###

echo "=========================================="
echo "MINECRAFT TIMER - TELEGRAM AUTH TEST"
echo "=========================================="
echo ""
echo "This will test the Telegram authentication flow."
echo ""

# Load configuration from config file
if [ -f "minertimer.config" ]; then
    source minertimer.config
    PLAYTIME_MINUTES=30
    EXTENSION_MINUTES=$((EXTENSION_TIME / 60))
else
    echo "⚠️  WARNING: minertimer.config not found!"
    echo "Using default values for testing..."
    TELEGRAM_BOT_TOKEN=""
    TELEGRAM_CHAT_ID=""
    EXTENSION_TIME=1800
    PLAYTIME_MINUTES=30
    EXTENSION_MINUTES=30
fi

if [ -z "$TELEGRAM_BOT_TOKEN" ] || [ -z "$TELEGRAM_CHAT_ID" ]; then
    echo "⚠️  WARNING: Telegram not configured in minertimer.sh"
    echo "Please set TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID first."
    echo ""
    read "?Press Enter to test without Telegram (password mode only)..."
else
    echo "✅ Telegram configured"
    echo "   Bot Token: ${TELEGRAM_BOT_TOKEN:0:20}..."
    echo "   Chat ID: $TELEGRAM_CHAT_ID"
    echo ""
    read "?Press Enter to start test..."
fi

# Ensure webhook is disabled so polling works
curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/deleteWebhook" > /dev/null 2>&1

echo ""

# Play sound and speak
afplay /System/Library/Sounds/Glass.aiff
say "Minecraft time has expired"

echo ""
echo "✅ Sound played and voice spoken"
echo "🎬 Now showing the first popup dialog..."
echo ""

# Show nice GUI dialog
DIALOG_RESULT=$(osascript <<EOF
try
    display dialog "⏰ TIME LIMIT REACHED!

You've played Minecraft for $PLAYTIME_MINUTES minutes today.

🎮 Want to keep playing?
Ask a parent for approval!

⏱️  Extension available: $EXTENSION_MINUTES more minutes" with title "⛏️  Minecraft Timer" buttons {"Close Minecraft", "Ask for More Time"} default button "Ask for More Time" with icon caution
    return button returned of result
on error
    return "TIMEOUT"
end try
EOF
)

echo "You clicked: $DIALOG_RESULT"
echo ""

# If user clicked "Ask for More Time", start authentication
if [[ $DIALOG_RESULT == "Ask for More Time" ]]; then

    # Check if Telegram is configured
    if [ -n "$TELEGRAM_BOT_TOKEN" ] && [ -n "$TELEGRAM_CHAT_ID" ]; then
        echo "📱 TELEGRAM MODE - Testing Telegram button authentication"
        echo ""

        # Get computer name
        COMPUTER_NAME=$(scutil --get ComputerName)

        # Get current time
        CURRENT_TIME=$(date "+%H:%M")

        # Create unique callback data to identify this specific request
        REQUEST_ID="test_$(date +%s)_$$"

        echo "Computer name: $COMPUTER_NAME"
        echo "Current time: $CURRENT_TIME"
        echo "Request ID: $REQUEST_ID"
        echo ""
        echo "📤 Sending Telegram message with approval buttons..."

        # Send Telegram message with inline keyboard
        TELEGRAM_MESSAGE="🎮 *MINECRAFT TIME REQUEST*%0A%0A💻 Computer: *${COMPUTER_NAME}*%0A⏰ Time: ${CURRENT_TIME}%0A⏱️  Played today: ${PLAYTIME_MINUTES} minutes%0A➕ Extension: ${EXTENSION_MINUTES} minutes%0A%0A👆 Tap a button to respond:"

        HTTP_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
            -d "chat_id=${TELEGRAM_CHAT_ID}" \
            -d "text=${TELEGRAM_MESSAGE}" \
            -d "parse_mode=Markdown" \
            -d "reply_markup={\"inline_keyboard\":[[{\"text\":\"✅ Approve ${EXTENSION_MINUTES} min\",\"callback_data\":\"approve_${REQUEST_ID}\"},{\"text\":\"❌ Deny\",\"callback_data\":\"deny_${REQUEST_ID}\"}]]}")

        HTTP_CODE=$(echo "$HTTP_RESPONSE" | tail -n1)

        if [ "$HTTP_CODE" = "200" ]; then
            echo "✅ Telegram message sent successfully!"
            echo "   Check your Telegram for the message with buttons."
        else
            echo "❌ Telegram message failed (HTTP $HTTP_CODE)"
            echo "   Response: $(echo "$HTTP_RESPONSE" | head -n-1)"
        fi

        echo ""
        echo "🎬 Now showing the waiting dialog..."
        echo "   (Click Cancel Request to test fallback, or tap a button in Telegram)"
        echo ""

        # NOTE: We don't clear updates here! We want to catch the button click from the message we just sent
        # Just get the current latest update_id to know where we are
        INITIAL_CHECK=$(curl -s "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/getUpdates?limit=1")
        LAST_UPDATE=$(echo "$INITIAL_CHECK" | grep -o '"update_id":[0-9]*' | tail -1 | cut -d':' -f2)
        if [ -z "$LAST_UPDATE" ]; then
            OFFSET=0
        else
            # Start from current offset, NOT +1, so we can catch any pending updates
            OFFSET=$LAST_UPDATE
        fi

        echo "Starting from offset: $OFFSET"

        # Show waiting dialog to kid in background
        osascript <<EOF > /dev/null 2>&1 &
display dialog "📱 WAITING FOR PARENT APPROVAL

A message was sent to your parents with Approve/Deny buttons.

⏳ Waiting for response...

This will timeout in 5 minutes." with title "⛏️  Minecraft Timer" buttons {"Cancel Request"} default button "Cancel Request" giving up after 300
EOF
        DIALOG_PID=$!

        # Poll for button click response (reduced to 30 polls of 5 seconds = 2.5 minutes for testing)
        BUTTON_RESULT="TIMEOUT"
        MAX_POLLS=30
        POLL_COUNT=0

        echo "⏳ Polling for parent response (checking every 5 seconds)..."

        while [ $POLL_COUNT -lt $MAX_POLLS ]; do
            # Check if dialog was closed/cancelled
            if ! kill -0 $DIALOG_PID 2>/dev/null; then
                BUTTON_RESULT="CANCELLED"
                echo "⏰ User cancelled the request"
                break
            fi

            # Poll Telegram for updates
            UPDATES=$(curl -s "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/getUpdates?offset=${OFFSET}&timeout=5")

            # If polling fails (e.g., webhook still configured), log and break
            if echo "$UPDATES" | grep -q '"ok":false'; then
                ERROR_DESC=$(echo "$UPDATES" | grep -o '"description":"[^"]*"' | head -1 | cut -d'"' -f4)
                echo "Telegram polling error: ${ERROR_DESC:-unknown error}"
                break
            fi

            # Check if we got any updates
            if echo "$UPDATES" | grep -q "\"result\""; then
                # Extract update ID first
                NEW_UPDATE_ID=$(echo "$UPDATES" | grep -o '"update_id":[0-9]*' | head -1 | cut -d':' -f2)

                # Update offset to not process this update again
                if [ -n "$NEW_UPDATE_ID" ]; then
                    OFFSET=$((NEW_UPDATE_ID + 1))
                fi

                # Check if it's a callback query
                if echo "$UPDATES" | grep -q "callback_query"; then
                    # Parse callback data robustly via Python (handles newlines/Unicode)
                    PY_OUT=$(UPDATES_JSON="$UPDATES" python3 - <<'PY'
import json,os,sys
raw=os.environ.get("UPDATES_JSON","")
try:
    data=json.loads(raw)
except Exception:
    print("\n\n")
    sys.exit()
cb=cbid=mid=""
for upd in data.get("result", []):
    cq=upd.get("callback_query") or {}
    if not cq:
        continue
    cb=cq.get("data") or cq.get("callback_data") or ""
    cbid=cq.get("id") or ""
    msg=cq.get("message") or {}
    mid=msg.get("message_id") or ""
    break
print(cb)
print(cbid)
print(mid)
PY
)
                    CALLBACK_DATA=$(echo "$PY_OUT" | sed -n '1p')
                    CALLBACK_QUERY_ID=$(echo "$PY_OUT" | sed -n '2p')
                    MESSAGE_ID=$(echo "$PY_OUT" | sed -n '3p')

                    echo "   📩 Received callback: '$CALLBACK_DATA'"
                    echo "   🔍 Looking for: approve_${REQUEST_ID} or deny_${REQUEST_ID}"
                    echo "   🐛 Length of CALLBACK_DATA: ${#CALLBACK_DATA}"

                    # Check if it's our request
                    if [[ $CALLBACK_DATA == "approve_${REQUEST_ID}" ]]; then
                        BUTTON_RESULT="APPROVED"
                        echo "   ✅ Parent approved!"

                        # Acknowledge the callback
                        curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/answerCallbackQuery" \
                            -d "callback_query_id=${CALLBACK_QUERY_ID}" \
                            -d "text=✅ Approved! Time granted." > /dev/null 2>&1

                        # Update the message
                        curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/editMessageText" \
                            -d "chat_id=${TELEGRAM_CHAT_ID}" \
                            -d "message_id=${MESSAGE_ID}" \
                            -d "text=${TELEGRAM_MESSAGE}%0A%0A✅ *APPROVED* by parent" \
                            -d "parse_mode=Markdown" > /dev/null 2>&1

                        break
                    elif [[ $CALLBACK_DATA == "deny_${REQUEST_ID}" ]]; then
                        BUTTON_RESULT="DENIED"
                        echo "   ❌ Parent denied!"

                        # Acknowledge the callback
                        curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/answerCallbackQuery" \
                            -d "callback_query_id=${CALLBACK_QUERY_ID}" \
                            -d "text=❌ Request denied." > /dev/null 2>&1

                        # Update the message
                        curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/editMessageText" \
                            -d "chat_id=${TELEGRAM_CHAT_ID}" \
                            -d "message_id=${MESSAGE_ID}" \
                            -d "text=${TELEGRAM_MESSAGE}%0A%0A❌ *DENIED* by parent" \
                            -d "parse_mode=Markdown" > /dev/null 2>&1

                        break
                    elif [ -n "$CALLBACK_QUERY_ID" ]; then
                        # Not our request - acknowledge to clear it and continue
                        echo "   ⏭️  Skipping old/unrelated callback: $CALLBACK_DATA"
                        curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/answerCallbackQuery" \
                            -d "callback_query_id=${CALLBACK_QUERY_ID}" > /dev/null 2>&1
                    fi
                fi
            fi

            POLL_COUNT=$((POLL_COUNT + 1))
            echo "   ⏳ Poll $POLL_COUNT/$MAX_POLLS - still waiting..."
        done

        # Close the waiting dialog if still open
        kill $DIALOG_PID 2>/dev/null

        echo ""

        # Process result based on button click
        CODE_RESULT="FAILED"
        if [[ $BUTTON_RESULT == "APPROVED" ]]; then
            CODE_RESULT="SUCCESS"
        fi

        # Process result
        if [[ $CODE_RESULT == "SUCCESS" ]]; then
            echo "🎬 Showing success dialog..."
            echo ""

            # Show success dialog
            osascript -e "display dialog \"✅ TIME EXTENSION GRANTED!

You've been granted $EXTENSION_MINUTES more minutes!

Enjoy your Minecraft adventure! ⛏️\" with title \"⛏️  Minecraft Timer\" buttons {\"Thanks!\"} default button \"Thanks!\" with icon note giving up after 10"

            say "Time extension granted. Enjoy!"

            echo "✅ TEST COMPLETE - Extension granted via Telegram button approval!"
        else
            # Failed - show fallback option
            echo "🎬 Showing fallback choice dialog..."
            echo ""

            FALLBACK_CHOICE=$(osascript <<EOF 2>/dev/null
try
    display dialog "❌ CODE VERIFICATION FAILED

All attempts used or timeout.

Do you have a parent nearby who can enter the admin password instead?" with title "⛏️  Minecraft Timer" buttons {"Close Minecraft", "Enter Admin Password"} default button "Enter Admin Password" with icon caution
    return button returned of result
on error
    return "CLOSE"
end try
EOF
)

            echo "Fallback choice: $FALLBACK_CHOICE"
            echo ""

            if [[ $FALLBACK_CHOICE == "Enter Admin Password" ]]; then
                echo "🎬 Showing admin password dialog..."
                echo ""

                # Use AppleScript to prompt for admin password
                PASSWORD_RESULT=$(osascript <<EOF 2>/dev/null
try
    set adminPassword to text returned of (display dialog "🔐 PARENT PASSWORD REQUIRED

Enter the administrator password to grant $EXTENSION_MINUTES more minutes of Minecraft play time." default answer "" with title "⛏️  Admin Authorization" buttons {"Cancel", "Grant Time"} default button "Grant Time" with hidden answer with icon note)

    -- Verify password using sudo
    do shell script "echo 'Password verified'" with administrator privileges password adminPassword
    return "SUCCESS"
on error
    return "FAILED"
end try
EOF
)

                if [[ $PASSWORD_RESULT == "SUCCESS" ]]; then
                    echo "✅ Admin password correct!"
                    echo ""

                    osascript -e "display dialog \"✅ TIME EXTENSION GRANTED!

You've been granted $EXTENSION_MINUTES more minutes!

Enjoy your Minecraft adventure! ⛏️\" with title \"⛏️  Minecraft Timer\" buttons {\"Thanks!\"} default button \"Thanks!\" with icon note giving up after 10"

                    say "Time extension granted. Enjoy!"

                    echo "✅ TEST COMPLETE - Extension granted via admin password!"
                else
                    echo "❌ Admin password failed"
                    echo ""

                    osascript -e "display dialog \"❌ INCORRECT PASSWORD

Minecraft will now close.
Better luck next time!\" with title \"⛏️  Minecraft Closed\" buttons {\"OK\"} default button \"OK\" with icon stop giving up after 10"

                    say "Authentication failed. Minecraft closing."

                    echo "✅ TEST COMPLETE - All authentication failed (Minecraft would close)"
                fi
            else
                echo "🎬 Showing time's up dialog..."
                echo ""

                osascript -e "display dialog \"⏰ TIME'S UP!

Minecraft is closing now.

See you tomorrow! 👋\" with title \"⛏️  Minecraft Closed\" buttons {\"OK\"} default button \"OK\" with icon note giving up after 10"

                say "Time limit reached. Minecraft closing."

                echo "✅ TEST COMPLETE - User declined fallback (Minecraft would close)"
            fi
        fi

    else
        # No Telegram configured - test password mode
        echo "🔑 PASSWORD MODE - Telegram not configured"
        echo "🎬 Now showing the password dialog..."
        echo ""

        PASSWORD_RESULT=$(osascript <<EOF 2>/dev/null
try
    set adminPassword to text returned of (display dialog "🔐 PARENT PASSWORD REQUIRED

Enter the administrator password to grant $EXTENSION_MINUTES more minutes of Minecraft play time." default answer "" with title "⛏️  Admin Authorization" buttons {"Cancel", "Grant Time"} default button "Grant Time" with hidden answer with icon note)

    -- Verify password using sudo
    do shell script "echo 'Password verified'" with administrator privileges password adminPassword
    return "SUCCESS"
on error
    return "FAILED"
end try
EOF
)

        echo "Password result: $PASSWORD_RESULT"
        echo ""

        if [[ $PASSWORD_RESULT == "SUCCESS" ]]; then
            echo "✅ Password was correct!"
            echo "🎬 Now showing the success dialog..."
            echo ""

            osascript -e "display dialog \"✅ TIME EXTENSION GRANTED!

You've been granted $EXTENSION_MINUTES more minutes!

Enjoy your Minecraft adventure! ⛏️\" with title \"⛏️  Minecraft Timer\" buttons {\"Thanks!\"} default button \"Thanks!\" with icon note giving up after 10"

            say "Time extension granted. Enjoy!"

            echo "✅ TEST COMPLETE - Extension granted via password!"
        else
            echo "❌ Password was incorrect or cancelled"
            echo "🎬 Now showing the failure dialog..."
            echo ""

            osascript -e "display dialog \"❌ INCORRECT PASSWORD

Minecraft will now close.
Better luck next time!\" with title \"⛏️  Minecraft Closed\" buttons {\"OK\"} default button \"OK\" with icon stop giving up after 10"

            say "Authentication failed. Minecraft closing."

            echo "✅ TEST COMPLETE - Password failed (Minecraft would close)"
        fi
    fi

else
    echo "⏰ User clicked Close Minecraft"
    echo "🎬 Now showing the time's up dialog..."
    echo ""

    osascript -e "display dialog \"⏰ TIME'S UP!

Minecraft is closing now.

See you tomorrow! 👋\" with title \"⛏️  Minecraft Closed\" buttons {\"OK\"} default button \"OK\" with icon note giving up after 10"

    say "Time limit reached. Minecraft closing."

    echo "✅ TEST COMPLETE - Cancelled (Minecraft would close)"
fi

echo ""
echo "=========================================="
echo "TEST FINISHED!"
echo "=========================================="
echo ""
echo "Summary:"
echo "- Telegram messages with buttons are sent to chat ID: $TELEGRAM_CHAT_ID"
echo "- Parents tap Approve/Deny buttons (no code entry needed!)"
echo "- System polls for response every 5 seconds"
echo "- Admin password is backup option if denied/timeout"
echo "- All dialogs have proper timeouts"
echo ""
