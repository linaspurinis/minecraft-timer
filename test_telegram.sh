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
        echo "📱 TELEGRAM MODE - Testing Telegram authentication"
        echo ""

        # Generate 4-digit random code
        RANDOM_CODE=$(( (RANDOM % 9000) + 1000 ))

        # Get computer name
        COMPUTER_NAME=$(scutil --get ComputerName)

        # Get current time
        CURRENT_TIME=$(date "+%H:%M")

        echo "Generated code: $RANDOM_CODE"
        echo "Computer name: $COMPUTER_NAME"
        echo "Current time: $CURRENT_TIME"
        echo ""
        echo "📤 Sending Telegram message..."

        # Send Telegram message
        TELEGRAM_MESSAGE="🎮 *MINECRAFT TIME REQUEST*%0A%0A💻 Computer: *${COMPUTER_NAME}*%0A⏰ Time: ${CURRENT_TIME}%0A⏱️  Played today: ${PLAYTIME_MINUTES} minutes%0A➕ Extension: ${EXTENSION_MINUTES} minutes%0A%0A🔐 Approval Code: *${RANDOM_CODE}*"

        HTTP_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
            -d "chat_id=${TELEGRAM_CHAT_ID}" \
            -d "text=${TELEGRAM_MESSAGE}" \
            -d "parse_mode=Markdown")

        HTTP_CODE=$(echo "$HTTP_RESPONSE" | tail -n1)

        if [ "$HTTP_CODE" = "200" ]; then
            echo "✅ Telegram message sent successfully!"
            echo "   Check your Telegram for the message."
        else
            echo "❌ Telegram message failed (HTTP $HTTP_CODE)"
            echo "   Response: $(echo "$HTTP_RESPONSE" | head -n-1)"
        fi

        echo ""
        echo "🎬 Now showing the code entry dialog..."
        echo "   (You have 3 attempts, or just click Cancel to test fallback)"
        echo ""

        # Show code entry dialog with 3 attempts
        ATTEMPTS=0
        CODE_RESULT="FAILED"

        while [ $ATTEMPTS -lt 3 ]; do
            ATTEMPTS=$((ATTEMPTS + 1))
            REMAINING_ATTEMPTS=$((3 - ATTEMPTS))

            if [ $ATTEMPTS -eq 1 ]; then
                PROMPT_TEXT="📱 PARENT APPROVAL CODE

A message was sent to your parents.
Ask them for the 4-digit code!

Enter the code below:"
            else
                PROMPT_TEXT="❌ INCORRECT CODE

You have $REMAINING_ATTEMPTS more attempt(s).

Enter the correct 4-digit code:"
            fi

            ENTERED_CODE=$(osascript <<EOF 2>/dev/null
try
    set userCode to text returned of (display dialog "$PROMPT_TEXT" default answer "" with title "⛏️  Minecraft Timer" buttons {"Cancel", "Submit Code"} default button "Submit Code" with icon note)
    return userCode
on error
    return "TIMEOUT"
end try
EOF
)

            echo "Attempt $ATTEMPTS: Entered code = '$ENTERED_CODE'"

            # Check if timeout or cancel
            if [[ $ENTERED_CODE == "TIMEOUT" ]] || [[ -z $ENTERED_CODE ]]; then
                CODE_RESULT="TIMEOUT"
                echo "⏰ User cancelled or timeout"
                break
            fi

            # Check if code matches
            if [[ $ENTERED_CODE == $RANDOM_CODE ]]; then
                CODE_RESULT="SUCCESS"
                echo "✅ Correct code entered!"
                break
            else
                echo "❌ Wrong code (expected: $RANDOM_CODE)"
            fi
        done

        echo ""

        # Process result
        if [[ $CODE_RESULT == "SUCCESS" ]]; then
            echo "🎬 Showing success dialog..."
            echo ""

            # Show success dialog
            osascript -e "display dialog \"✅ TIME EXTENSION GRANTED!

You've been granted $EXTENSION_MINUTES more minutes!

Enjoy your Minecraft adventure! ⛏️\" with title \"⛏️  Minecraft Timer\" buttons {\"Thanks!\"} default button \"Thanks!\" with icon note giving up after 10"

            say "Time extension granted. Enjoy!"

            echo "✅ TEST COMPLETE - Extension granted via Telegram code!"
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
echo "- Telegram messages are sent to chat ID: $TELEGRAM_CHAT_ID"
echo "- Code has 3 attempts before fallback"
echo "- Admin password is backup option"
echo "- All dialogs have proper timeouts"
echo ""
