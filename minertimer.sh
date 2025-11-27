#!/bin/zsh

###
# Minecraft Timer - Parental control for Minecraft Java Edition on macOS
# Copyright (c) 2025 Linas Purinis
# Based on original work by Soferio Pty Limited
# Open source project: https://github.com/linaspurinis/minecraft-timer
###

# CONFIGURATION - Load from config file
# The configuration is stored in minertimer.config (see minertimer.config.example)

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/minertimer.config"

# Set default values
TIME_LIMIT=1800
WEEKEND_TIME_LIMIT=3600
EXTENSION_TIME=1800
DISPLAY_5_MIN_WARNING=true
DISPLAY_1_MIN_WARNING=true
REQUIRE_ADMIN_PASSWORD=true
ENABLE_TELEGRAM_AUTH=false
TELEGRAM_BOT_TOKEN=""
TELEGRAM_CHAT_ID=""

# Kill Minecraft using fresh PID lookup to avoid missing relaunches during prompts
kill_minecraft_instances() {
    local pids
    # Match both the Minecraft process name and Java processes with -Xdock:name=Minecraft
    # This catches both native Minecraft and Java-based Minecraft
    pids=$(ps aux | grep -E "(^[^ ]+ +[0-9]+ .*/java .* -Xdock:name=Minecraft|[M]inecraft)" | grep -v grep | awk '{print $2}')
    if [ -n "$pids" ]; then
        echo "Killing Minecraft instances: $pids"
        echo "$pids" | xargs kill 2>/dev/null
        sleep 2
        # Retry with -9 in case the first signal was ignored
        pids=$(ps aux | grep -E "(^[^ ]+ +[0-9]+ .*/java .* -Xdock:name=Minecraft|[M]inecraft)" | grep -v grep | awk '{print $2}')
        if [ -n "$pids" ]; then
            echo "Force killing remaining Minecraft instances: $pids"
            echo "$pids" | xargs kill -9 2>/dev/null
        fi
    fi
}

# Ensure Telegram is in polling mode (no webhook) so inline button callbacks are delivered
ensure_telegram_polling_mode() {
    if [ -n "$TELEGRAM_BOT_TOKEN" ]; then
        curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/deleteWebhook" > /dev/null 2>&1
    fi
}

# Check if config file exists and load it
if [ -f "$CONFIG_FILE" ]; then
    echo "Loading configuration from: $CONFIG_FILE"
    source "$CONFIG_FILE"
else
    echo "WARNING: Configuration file not found: $CONFIG_FILE"
    echo "Using default settings (Telegram disabled, password authentication only)"
    echo "To enable Telegram: copy minertimer.config.example to minertimer.config"
fi

# Validate required settings
if [ -z "$TIME_LIMIT" ] || [ -z "$WEEKEND_TIME_LIMIT" ] || [ -z "$EXTENSION_TIME" ]; then
    echo "ERROR: Missing required time limit settings"
    echo "Please check your configuration file or use defaults"
    exit 1
fi

# Directory and file to store total played time for the day
LOG_DIRECTORY="/var/lib/minertimer"
LOG_FILE="${LOG_DIRECTORY}/minertimer_playtime.log"

# Create the directory with restricted permissions (don't throw error if already exists)
if [ ! -d "$LOG_DIRECTORY" ]; then
    mkdir -p "$LOG_DIRECTORY"
    chmod 700 "$LOG_DIRECTORY"
fi

# Get the current date
CURRENT_DATE=$(date +%Y-%m-%d)

# Read the last play date, total played time, and extended time from the log file
# Log file format: line 1 = date, line 2 = total_played_time, line 3 = extended_time
if [ -f "$LOG_FILE" ]; then
    LAST_PLAY_DATE=$(sed -n '1p' "$LOG_FILE")
    TOTAL_PLAYED_TIME=$(sed -n '2p' "$LOG_FILE")
    EXTENDED_TIME=$(sed -n '3p' "$LOG_FILE")

    # Validate numeric values
    if ! [[ "$TOTAL_PLAYED_TIME" =~ ^[0-9]+$ ]]; then
        TOTAL_PLAYED_TIME=0
    fi
    if ! [[ "$EXTENDED_TIME" =~ ^[0-9]+$ ]]; then
        EXTENDED_TIME=0
    fi
else
    LAST_PLAY_DATE="$CURRENT_DATE"
    TOTAL_PLAYED_TIME=0
    EXTENDED_TIME=0
    echo "$CURRENT_DATE" > "$LOG_FILE"
    echo "0" >> "$LOG_FILE"
    echo "0" >> "$LOG_FILE"
    chmod 600 "$LOG_FILE"
fi

 # If it's a new day, or first use, reset the playtime and extensions
if [ "$LAST_PLAY_DATE" != "$CURRENT_DATE" ]; then
    TOTAL_PLAYED_TIME=0
    EXTENDED_TIME=0
    echo "$CURRENT_DATE" > "$LOG_FILE"
    echo "0" >> "$LOG_FILE"
    echo "0" >> "$LOG_FILE"
    chmod 600 "$LOG_FILE"
fi

while true; do
    
    MINECRAFT_PIDS=$(ps aux | grep -iww "[M]inecraft" | awk '{print $2}')
    # If Minecraft is running
    
    if [ -n "$MINECRAFT_PIDS" ]; then
        # Set base limit based on day of week
        base_limit=$TIME_LIMIT
        if [[ $(date +%u) -gt 5 ]]; then
            base_limit=$WEEKEND_TIME_LIMIT
        fi
        # Add any granted extensions to the base limit
        current_limit=$((base_limit + EXTENDED_TIME))

        # If the time limit has been reached, prompt for extension
        if ((TOTAL_PLAYED_TIME >= current_limit)); then
            # Play sound and show notification
            afplay /System/Library/Sounds/Glass.aiff
            say "Minecraft time has expired"

            # Create message
            PLAYTIME_MINUTES=$((TOTAL_PLAYED_TIME / 60))
            EXTENSION_MINUTES=$((EXTENSION_TIME / 60))

            # Show nice GUI dialog with 5 minute timeout (Minecraft still running during this time)
            DIALOG_RESULT=$(osascript <<EOF
try
    display dialog "⏰ TIME LIMIT REACHED!

You've played Minecraft for $PLAYTIME_MINUTES minutes today.

🎮 Want to keep playing?
Ask a parent for approval!

⏱️  Extension available: $EXTENSION_MINUTES more minutes" with title "⛏️  Minecraft Timer" buttons {"Close Minecraft", "Ask for More Time"} default button "Ask for More Time" with icon caution giving up after 300
    return button returned of result
on error
    return "TIMEOUT"
end try
EOF
)

            # If user clicked "Ask for More Time", start authentication process
            if [[ $DIALOG_RESULT == "Ask for More Time" ]]; then

                # Check if Telegram auth is enabled and configured
                if [ "$ENABLE_TELEGRAM_AUTH" = true ] && [ -n "$TELEGRAM_BOT_TOKEN" ] && [ -n "$TELEGRAM_CHAT_ID" ]; then
                    # TELEGRAM BUTTON AUTHENTICATION

                    # Get computer name
                    COMPUTER_NAME=$(scutil --get ComputerName)

                    # Get current time
                    CURRENT_TIME=$(date "+%H:%M")

                    # Create unique callback data to identify this specific request
                    REQUEST_ID="req_$(date +%s)_$$"

                    # Send Telegram message with inline keyboard buttons
                    TELEGRAM_MESSAGE="🎮 *MINECRAFT TIME REQUEST*%0A%0A💻 Computer: *${COMPUTER_NAME}*%0A⏰ Time: ${CURRENT_TIME}%0A⏱️  Played today: ${PLAYTIME_MINUTES} minutes%0A➕ Extension: ${EXTENSION_MINUTES} minutes%0A%0A👆 Tap a button to respond:"

                    # Send message with inline keyboard
                    SEND_RESPONSE=$(curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
                        -d "chat_id=${TELEGRAM_CHAT_ID}" \
                        -d "text=${TELEGRAM_MESSAGE}" \
                        -d "parse_mode=Markdown" \
                        -d "reply_markup={\"inline_keyboard\":[[{\"text\":\"✅ Approve ${EXTENSION_MINUTES} min\",\"callback_data\":\"approve_${REQUEST_ID}\"},{\"text\":\"❌ Deny\",\"callback_data\":\"deny_${REQUEST_ID}\"}]]}")

                    echo "Telegram message sent with approval buttons"

                    # Ensure webhook is disabled so getUpdates works; if webhook is set Telegram will ignore polling
                    ensure_telegram_polling_mode

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

                    # Show waiting dialog to kid
                    osascript <<EOF > /dev/null 2>&1 &
display dialog "📱 WAITING FOR PARENT APPROVAL

A message was sent to your parents with Approve/Deny buttons.

⏳ Waiting for response...

This will timeout in 5 minutes." with title "⛏️  Minecraft Timer" buttons {"Cancel Request"} default button "Cancel Request" giving up after 300
EOF
                    DIALOG_PID=$!

                    # Poll for button click response (5 minute timeout = 60 polls of 5 seconds each)
                    BUTTON_RESULT="TIMEOUT"
                    MAX_POLLS=60
                    POLL_COUNT=0

                    while [ $POLL_COUNT -lt $MAX_POLLS ]; do
                        # Check if dialog was closed/cancelled
                        if ! kill -0 $DIALOG_PID 2>/dev/null; then
                            BUTTON_RESULT="CANCELLED"
                            break
                        fi

                        # Poll Telegram for updates with 5 second timeout
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
                                # Parse callback data robustly (handles newlines/Unicode) via Python
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


                                # Check if it's our request
                                if [[ $CALLBACK_DATA == "approve_${REQUEST_ID}" ]]; then
                                    BUTTON_RESULT="APPROVED"

                                    # Acknowledge the callback
                                    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/answerCallbackQuery" \
                                        -d "callback_query_id=${CALLBACK_QUERY_ID}" \
                                        -d "text=✅ Approved! Time granted." > /dev/null 2>&1

                                    # Update the message to show it was approved
                                    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/editMessageText" \
                                        -d "chat_id=${TELEGRAM_CHAT_ID}" \
                                        -d "message_id=${MESSAGE_ID}" \
                                        -d "text=${TELEGRAM_MESSAGE}%0A%0A✅ *APPROVED* by parent" \
                                        -d "parse_mode=Markdown" > /dev/null 2>&1

                                    break
                                elif [[ $CALLBACK_DATA == "deny_${REQUEST_ID}" ]]; then
                                    BUTTON_RESULT="DENIED"

                                    # Acknowledge the callback
                                    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/answerCallbackQuery" \
                                        -d "callback_query_id=${CALLBACK_QUERY_ID}" \
                                        -d "text=❌ Request denied." > /dev/null 2>&1

                                    # Update the message to show it was denied
                                    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/editMessageText" \
                                        -d "chat_id=${TELEGRAM_CHAT_ID}" \
                                        -d "message_id=${MESSAGE_ID}" \
                                        -d "text=${TELEGRAM_MESSAGE}%0A%0A❌ *DENIED* by parent" \
                                        -d "parse_mode=Markdown" > /dev/null 2>&1

                                    break
                                elif [ -n "$CALLBACK_QUERY_ID" ]; then
                                    # Not our request - acknowledge to clear it and continue
                                    echo "Skipping old/unrelated callback: $CALLBACK_DATA"
                                    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/answerCallbackQuery" \
                                        -d "callback_query_id=${CALLBACK_QUERY_ID}" > /dev/null 2>&1
                                fi
                            fi
                        fi

                        POLL_COUNT=$((POLL_COUNT + 1))
                    done

                    # Close the waiting dialog if still open
                    kill $DIALOG_PID 2>/dev/null

                    # Process result based on button click
                    CODE_RESULT="FAILED"
                    if [[ $BUTTON_RESULT == "APPROVED" ]]; then
                        CODE_RESULT="SUCCESS"
                    fi

                    # Process result
                    if [[ $CODE_RESULT == "SUCCESS" ]]; then
                        # Add extension time to the extended time counter
                        EXTENDED_TIME=$((EXTENDED_TIME + EXTENSION_TIME))
                        current_limit=$((base_limit + EXTENDED_TIME))
                        echo "Extension granted via Telegram button! New limit: $((current_limit / 60)) minutes"

                        # Show success dialog
                        osascript -e "display dialog \"✅ TIME EXTENSION GRANTED!

You've been granted $EXTENSION_MINUTES more minutes!

Enjoy your Minecraft adventure! ⛏️\" with title \"⛏️  Minecraft Timer\" buttons {\"Thanks!\"} default button \"Thanks!\" with icon note giving up after 5"

                        say "Time extension granted. Enjoy!"
                        # Reset warnings for next cycle
                        DISPLAY_5_MIN_WARNING=true
                        DISPLAY_1_MIN_WARNING=true
                    else
                        # Code failed or timeout - Close Minecraft first
                        echo "Code verification failed. Closing Minecraft..."
                        kill_minecraft_instances

                        # Now offer fallback option or show final message
                        if [ "$REQUIRE_ADMIN_PASSWORD" = true ]; then
                            # Offer admin password as fallback
                            FALLBACK_CHOICE=$(osascript <<EOF 2>/dev/null
try
    display dialog "❌ CODE VERIFICATION FAILED

All attempts used or timeout.

Do you have a parent nearby who can enter the admin password instead?" with title "⛏️  Minecraft Timer" buttons {"Close Minecraft", "Enter Admin Password"} default button "Enter Admin Password" with icon caution giving up after 60
    return button returned of result
on error
    return "CLOSE"
end try
EOF
)

                            if [[ $FALLBACK_CHOICE == "Enter Admin Password" ]]; then
                                # Use AppleScript to prompt for admin password with nice dialog (5 minute timeout)
                                PASSWORD_RESULT=$(osascript <<EOF 2>/dev/null
try
    set adminPassword to text returned of (display dialog "🔐 PARENT PASSWORD REQUIRED

Enter the administrator password to grant $EXTENSION_MINUTES more minutes of Minecraft play time." default answer "" with title "⛏️  Admin Authorization" buttons {"Cancel", "Grant Time"} default button "Grant Time" with hidden answer with icon note giving up after 300)

    -- Verify password using sudo
    do shell script "echo 'Password verified'" with administrator privileges password adminPassword
    return "SUCCESS"
on error
    return "FAILED"
end try
EOF
)

                                if [[ $PASSWORD_RESULT == "SUCCESS" ]]; then
                                    # Add extension time to the extended time counter
                                    EXTENDED_TIME=$((EXTENDED_TIME + EXTENSION_TIME))
                                    current_limit=$((base_limit + EXTENDED_TIME))
                                    echo "Extension granted via admin password! New limit: $((current_limit / 60)) minutes"

                                    # Show success dialog
                                    osascript -e "display dialog \"✅ TIME EXTENSION GRANTED!

You've been granted $EXTENSION_MINUTES more minutes!

You can now reopen Minecraft and play! ⛏️\" with title \"⛏️  Minecraft Timer\" buttons {\"Open Minecraft\"} default button \"Open Minecraft\" with icon note giving up after 10"

                                    say "Time extension granted. You can now reopen Minecraft!"

                                    # Open Minecraft for them
                                    open -a Minecraft
                                    # Reset warnings for next cycle
                                    DISPLAY_5_MIN_WARNING=true
                                    DISPLAY_1_MIN_WARNING=true
                                else
                                    echo "Admin password failed."
                                    osascript -e "display dialog \"❌ INCORRECT PASSWORD

Minecraft has been closed.
Better luck next time!\" with title \"⛏️  Minecraft Closed\" buttons {\"OK\"} default button \"OK\" with icon stop giving up after 5"
                                    say "Authentication failed."
                                fi
                            else
                                # User chose not to continue
                                echo "User declined admin password."
                                osascript -e "display dialog \"⏰ TIME'S UP!

Minecraft has been closed.

See you tomorrow! 👋\" with title \"⛏️  Minecraft Closed\" buttons {\"OK\"} default button \"OK\" with icon note giving up after 5"
                                say "Time limit reached."
                            fi
                        else
                            # No admin password fallback available
                            echo "Code verification failed."
                            osascript -e "display dialog \"⏰ TIME'S UP!

Minecraft has been closed.

See you tomorrow! 👋\" with title \"⛏️  Minecraft Closed\" buttons {\"OK\"} default button \"OK\" with icon note giving up after 5"
                            say "Time limit reached."
                        fi
                    fi

                elif [ "$REQUIRE_ADMIN_PASSWORD" = true ]; then
                    # FALLBACK: Password-only mode (Telegram disabled or not configured)
                    # Use AppleScript to prompt for admin password with nice dialog (5 minute timeout)
                    # Minecraft stays open during this time (like the Telegram code entry)
                    PASSWORD_RESULT=$(osascript <<EOF 2>/dev/null
try
    set adminPassword to text returned of (display dialog "🔐 PARENT PASSWORD REQUIRED

Enter the administrator password to grant $EXTENSION_MINUTES more minutes of Minecraft play time." default answer "" with title "⛏️  Admin Authorization" buttons {"Cancel", "Grant Time"} default button "Grant Time" with hidden answer with icon note giving up after 300)

    -- Verify password using sudo
    do shell script "echo 'Password verified'" with administrator privileges password adminPassword
    return "SUCCESS"
on error
    return "FAILED"
end try
EOF
)

                    if [[ $PASSWORD_RESULT == "SUCCESS" ]]; then
                        # Add extension time to the extended time counter
                        EXTENDED_TIME=$((EXTENDED_TIME + EXTENSION_TIME))
                        current_limit=$((base_limit + EXTENDED_TIME))
                        echo "Extension granted via admin password! New limit: $((current_limit / 60)) minutes"

                        # Show success dialog
                        osascript -e "display dialog \"✅ TIME EXTENSION GRANTED!

You've been granted $EXTENSION_MINUTES more minutes!

Enjoy your Minecraft adventure! ⛏️\" with title \"⛏️  Minecraft Timer\" buttons {\"Thanks!\"} default button \"Thanks!\" with icon note giving up after 5"

                        say "Time extension granted. Enjoy!"
                        # Reset warnings for next cycle
                        DISPLAY_5_MIN_WARNING=true
                        DISPLAY_1_MIN_WARNING=true
                    else
                        # Password failed or cancelled - Close Minecraft
                        echo "Authentication failed. Closing Minecraft..."
                        kill_minecraft_instances

                        osascript -e "display dialog \"❌ INCORRECT PASSWORD

Minecraft has been closed.
Better luck next time!\" with title \"⛏️  Minecraft Closed\" buttons {\"OK\"} default button \"OK\" with icon stop giving up after 5"
                        say "Authentication failed. Minecraft closing."
                    fi
                else
                    # No authentication enabled - should not happen
                    echo "No authentication method enabled."
                    osascript -e "display dialog \"⏰ TIME'S UP!

Minecraft has been closed.

See you tomorrow! 👋\" with title \"⛏️  Minecraft Closed\" buttons {\"OK\"} default button \"OK\" with icon note giving up after 5"
                    say "Time limit reached."
                fi
            else
                # User clicked "Close Minecraft" or timeout on initial dialog
                echo "Extension denied. Closing Minecraft..."
                kill_minecraft_instances

                osascript -e "display dialog \"⏰ TIME'S UP!

Minecraft has been closed.

See you tomorrow! 👋\" with title \"⛏️  Minecraft Closed\" buttons {\"OK\"} default button \"OK\" with icon note giving up after 5"
                say "Time limit reached. Minecraft closing."
            fi 
        elif ((TOTAL_PLAYED_TIME >= current_limit - 300)) && [ "$DISPLAY_5_MIN_WARNING" = true ]; then
            osascript -e 'display notification "Minecraft will exit in 5 minutes" with title "Minecraft Time Expiring Soon"'
            say "Minecraft time will expire in 5 minutes"
            DISPLAY_5_MIN_WARNING=false
        elif ((TOTAL_PLAYED_TIME >= current_limit - 60)) && [ "$DISPLAY_1_MIN_WARNING" = true ]; then
            osascript -e 'display notification "Minecraft will exit in 1 minute" with title "Minecraft Time Expiring"'
            say "Minecraft time will expire in 1 minute"
            DISPLAY_1_MIN_WARNING=false
        fi
        
        # Sleep, then increment the playtime
        sleep 20
        TOTAL_PLAYED_TIME=$((TOTAL_PLAYED_TIME + 20))

        # Update the log file with current played time and extensions
        # Log file format: line 1 = date, line 2 = total_played_time, line 3 = extended_time
        sed -i '' "2s/.*/$TOTAL_PLAYED_TIME/" "$LOG_FILE"
        sed -i '' "3s/.*/$EXTENDED_TIME/" "$LOG_FILE"

    else
        sleep 10
    fi

    # Get the current date
    CURRENT_DATE=$(date +%Y-%m-%d)

    # Read the last play date from the log file
    if [ -f "$LOG_FILE" ]; then
        LAST_PLAY_DATE=$(head -n 1 "$LOG_FILE")
    else
        # This error should not happen because log file created above
        echo "ERROR - NO LOG FILE"
    fi

    # If it's a new day, reset the playtime and extensions
    if [ "$LAST_PLAY_DATE" != "$CURRENT_DATE" ]; then
        TOTAL_PLAYED_TIME=0
        EXTENDED_TIME=0
        DISPLAY_5_MIN_WARNING=true
        DISPLAY_1_MIN_WARNING=true
        echo "$CURRENT_DATE" > "$LOG_FILE"
        echo "0" >> "$LOG_FILE"
        echo "0" >> "$LOG_FILE"
        chmod 600 "$LOG_FILE"
        echo "RESET DATE - $CURRENT_DATE"
    fi
done
