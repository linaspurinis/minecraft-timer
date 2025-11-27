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

# Create the directory (don't throw error if already exists)
mkdir -p $LOG_DIRECTORY

# Get the current date
CURRENT_DATE=$(date +%Y-%m-%d)

# Read the last play date and total played time from the log file
if [ -f "$LOG_FILE" ]; then
    LAST_PLAY_DATE=$(head -n 1 "$LOG_FILE")
    TOTAL_PLAYED_TIME=$(tail -n 1 "$LOG_FILE")
else
    LAST_PLAY_DATE="$CURRENT_DATE"
    TOTAL_PLAYED_TIME=0
    echo "$CURRENT_DATE" > "$LOG_FILE"
    echo "0" >> "$LOG_FILE"
fi

 # If it's a new day, or first use, reset the playtime
if [ "$LAST_PLAY_DATE" != "$CURRENT_DATE" ]; then
    TOTAL_PLAYED_TIME=0
    echo "$CURRENT_DATE" > "$LOG_FILE"
    echo "0" >> "$LOG_FILE"
fi

# Initialize the current limit (will be increased if extensions are granted)
EXTENDED_TIME=0

while true; do
    
    MINECRAFT_PIDS=$(ps aux | grep -iww "[M]inecraft" | awk '{print $2}')
    # If Minecraft is running
    
    if [ -n "$MINECRAFT_PIDS" ]; then
        # Set base limit based on day of week
        base_limit=TIME_LIMIT
        if [[ $(date +%u) -gt 5 ]]; then
            base_limit=WEEKEND_TIME_LIMIT
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

            # Show nice GUI dialog with 5 minute timeout
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
                    # TELEGRAM CODE AUTHENTICATION

                    # Generate 4-digit random code
                    RANDOM_CODE=$(( (RANDOM % 9000) + 1000 ))

                    # Get computer name
                    COMPUTER_NAME=$(scutil --get ComputerName)

                    # Get current time
                    CURRENT_TIME=$(date "+%H:%M")

                    # Send Telegram message
                    TELEGRAM_MESSAGE="🎮 *MINECRAFT TIME REQUEST*%0A%0A💻 Computer: *${COMPUTER_NAME}*%0A⏰ Time: ${CURRENT_TIME}%0A⏱️  Played today: ${PLAYTIME_MINUTES} minutes%0A➕ Extension: ${EXTENSION_MINUTES} minutes%0A%0A🔐 Approval Code: *${RANDOM_CODE}*"

                    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
                        -d "chat_id=${TELEGRAM_CHAT_ID}" \
                        -d "text=${TELEGRAM_MESSAGE}" \
                        -d "parse_mode=Markdown" > /dev/null 2>&1

                    echo "Telegram message sent. Code: $RANDOM_CODE"

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
    set userCode to text returned of (display dialog "$PROMPT_TEXT" default answer "" with title "⛏️  Minecraft Timer" buttons {"Cancel", "Submit Code"} default button "Submit Code" with icon note giving up after 300)
    return userCode
on error
    return "TIMEOUT"
end try
EOF
)

                        # Check if timeout or cancel
                        if [[ $ENTERED_CODE == "TIMEOUT" ]] || [[ -z $ENTERED_CODE ]]; then
                            CODE_RESULT="TIMEOUT"
                            break
                        fi

                        # Check if code matches
                        if [[ $ENTERED_CODE == $RANDOM_CODE ]]; then
                            CODE_RESULT="SUCCESS"
                            break
                        fi
                    done

                    # Process result
                    if [[ $CODE_RESULT == "SUCCESS" ]]; then
                        # Add extension time to the extended time counter
                        EXTENDED_TIME=$((EXTENDED_TIME + EXTENSION_TIME))
                        current_limit=$((base_limit + EXTENDED_TIME))
                        echo "Extension granted via Telegram code! New limit: $((current_limit / 60)) minutes"

                        # Show success dialog
                        osascript -e "display dialog \"✅ TIME EXTENSION GRANTED!

You've been granted $EXTENSION_MINUTES more minutes!

Enjoy your Minecraft adventure! ⛏️\" with title \"⛏️  Minecraft Timer\" buttons {\"Thanks!\"} default button \"Thanks!\" with icon note giving up after 5"

                        say "Time extension granted. Enjoy!"
                        # Reset warnings for next cycle
                        DISPLAY_5_MIN_WARNING=true
                        DISPLAY_1_MIN_WARNING=true
                    else
                        # Failed - show fallback option or close
                        if [ "$REQUIRE_ADMIN_PASSWORD" = true ]; then
                            # Offer admin password as fallback
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

Enjoy your Minecraft adventure! ⛏️\" with title \"⛏️  Minecraft Timer\" buttons {\"Thanks!\"} default button \"Thanks!\" with icon note giving up after 5"

                                    say "Time extension granted. Enjoy!"
                                    # Reset warnings for next cycle
                                    DISPLAY_5_MIN_WARNING=true
                                    DISPLAY_1_MIN_WARNING=true
                                else
                                    echo "Admin password failed. Closing Minecraft..."
                                    echo $MINECRAFT_PIDS | xargs kill

                                    osascript -e "display dialog \"❌ INCORRECT PASSWORD

Minecraft will now close.
Better luck next time!\" with title \"⛏️  Minecraft Closed\" buttons {\"OK\"} default button \"OK\" with icon stop giving up after 5"
                                    say "Authentication failed. Minecraft closing."
                                fi
                            else
                                # User chose to close Minecraft
                                echo "User declined admin password. Closing Minecraft..."
                                echo $MINECRAFT_PIDS | xargs kill

                                osascript -e "display dialog \"⏰ TIME'S UP!

Minecraft is closing now.

See you tomorrow! 👋\" with title \"⛏️  Minecraft Closed\" buttons {\"OK\"} default button \"OK\" with icon note giving up after 5"
                                say "Time limit reached. Minecraft closing."
                            fi
                        else
                            # No admin password fallback available
                            echo "Code verification failed. Closing Minecraft..."
                            echo $MINECRAFT_PIDS | xargs kill

                            osascript -e "display dialog \"⏰ TIME'S UP!

Minecraft is closing now.

See you tomorrow! 👋\" with title \"⛏️  Minecraft Closed\" buttons {\"OK\"} default button \"OK\" with icon note giving up after 5"
                            say "Time limit reached. Minecraft closing."
                        fi
                    fi

                elif [ "$REQUIRE_ADMIN_PASSWORD" = true ]; then
                    # FALLBACK: Password-only mode (Telegram disabled or not configured)
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

Enjoy your Minecraft adventure! ⛏️\" with title \"⛏️  Minecraft Timer\" buttons {\"Thanks!\"} default button \"Thanks!\" with icon note giving up after 5"

                        say "Time extension granted. Enjoy!"
                        # Reset warnings for next cycle
                        DISPLAY_5_MIN_WARNING=true
                        DISPLAY_1_MIN_WARNING=true
                    else
                        echo "Authentication failed. Closing Minecraft..."
                        echo $MINECRAFT_PIDS | xargs kill

                        osascript -e "display dialog \"❌ INCORRECT PASSWORD

Minecraft will now close.
Better luck next time!\" with title \"⛏️  Minecraft Closed\" buttons {\"OK\"} default button \"OK\" with icon stop giving up after 5"
                        say "Authentication failed. Minecraft closing."
                    fi
                else
                    # No authentication enabled - should not happen
                    echo "No authentication method enabled. Closing Minecraft..."
                    echo $MINECRAFT_PIDS | xargs kill

                    osascript -e "display dialog \"⏰ TIME'S UP!

Minecraft is closing now.

See you tomorrow! 👋\" with title \"⛏️  Minecraft Closed\" buttons {\"OK\"} default button \"OK\" with icon note giving up after 5"
                    say "Time limit reached. Minecraft closing."
                fi
            else
                # User clicked "Close Minecraft" or timeout
                echo "Extension denied. Closing Minecraft..."
                echo $MINECRAFT_PIDS | xargs kill

                osascript -e "display dialog \"⏰ TIME'S UP!

Minecraft is closing now.

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

        # Update the total played time in the log file (Note on mac -i requires extension)
        sed -i '' "$ s/.*/$TOTAL_PLAYED_TIME/" "$LOG_FILE"

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
        echo "RESET DATE - $CURRENT_DATE"
    fi
done