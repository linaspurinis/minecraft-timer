#!/bin/zsh

###
# TEST SCRIPT - Shows the Minecraft timer popups without needing to run Minecraft
# This simulates what your kid will see when the time limit is reached
###

echo "=========================================="
echo "MINECRAFT TIMER - POPUP TEST"
echo "=========================================="
echo ""
echo "This will show you the exact popups your kid will see"
echo "when the Minecraft time limit is reached."
echo ""
echo "Press Enter to see the popups..."
read

# Configuration from main script
EXTENSION_TIME=1800
PLAYTIME_MINUTES=30
EXTENSION_MINUTES=$((EXTENSION_TIME / 60))

# Play sound and speak
afplay /System/Library/Sounds/Glass.aiff
say "Minecraft time has expired"

echo ""
echo "✅ Sound played and voice spoken"
echo "🎬 Now showing the first popup dialog..."
echo ""

# Show nice GUI dialog
DIALOG_RESULT=$(osascript <<EOF
display dialog "⏰ TIME LIMIT REACHED!

You've played Minecraft for $PLAYTIME_MINUTES minutes today.

🎮 Want to keep playing?
Ask a parent to enter the admin password!

⏱️  Extension available: $EXTENSION_MINUTES more minutes" with title "⛏️  Minecraft Timer" buttons {"Close Minecraft", "Ask for More Time"} default button "Ask for More Time" with icon caution
return button returned of result
EOF
)

echo "You clicked: $DIALOG_RESULT"
echo ""

# If user clicked "Ask for More Time", prompt for password
if [[ $DIALOG_RESULT == "Ask for More Time" ]]; then
    echo "🎬 Now showing the password dialog..."
    echo ""

    # Use AppleScript to prompt for admin password with nice dialog
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

        # Show success dialog
        osascript -e "display dialog \"✅ TIME EXTENSION GRANTED!

You've been granted $EXTENSION_MINUTES more minutes!

Enjoy your Minecraft adventure! ⛏️\" with title \"⛏️  Minecraft Timer\" buttons {\"Thanks!\"} default button \"Thanks!\" with icon note giving up after 10"

        say "Time extension granted. Enjoy!"

        echo "✅ TEST COMPLETE - Extension granted!"
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
echo "This is exactly what your kid will see when"
echo "the Minecraft timer reaches its limit."
echo ""
