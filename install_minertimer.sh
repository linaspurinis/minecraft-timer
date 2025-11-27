#!/bin/zsh

###
# Minecraft Timer Installation Script
# Copyright (c) 2025 Linas Purinis
# Requires administrator privileges
###

# Check if configuration file exists
if [ ! -f "minertimer.config" ]; then
    echo ""
    echo "⚠️  ERROR: Configuration file 'minertimer.config' not found!"
    echo ""
    echo "Please create your configuration file first:"
    echo "  1. Copy minertimer.config.example to minertimer.config"
    echo "  2. Edit minertimer.config and add your settings"
    echo "  3. Run this install script again"
    echo ""
    exit 1
fi

echo ""
echo "Installing Minecraft Timer..."
echo ""

# Step 1: Place Minertime script and config where they belong (and create directory if necessary)

mkdir -p /Users/Shared/minertimer
cp minertimer.sh /Users/Shared/minertimer/
cp minertimer.config /Users/Shared/minertimer/
chmod +x /Users/Shared/minertimer/minertimer.sh
chmod 600 /Users/Shared/minertimer/minertimer.config  # Restrict config file permissions

echo "✅ Copied minertimer.sh and minertimer.config to /Users/Shared/minertimer/"

# Step 2: Place the PLIST file where it belongs

cp com.purinis.minecrafttimer.plist /Library/LaunchDaemons/
chown root:wheel /Library/LaunchDaemons/com.purinis.minecrafttimer.plist
chmod 644 /Library/LaunchDaemons/com.purinis.minecrafttimer.plist

echo "✅ Installed LaunchDaemon plist file"

# Step 3: Register the minertimer as a background task

launchctl load -w /Library/LaunchDaemons/com.purinis.minecrafttimer.plist

echo "✅ Registered and started background service"

# Step 4: Post Script report
echo ""
echo "=========================================="
echo "✅ INSTALLATION COMPLETE!"
echo "=========================================="
echo ""
echo "To verify the timer is running:"
echo "  sudo launchctl list | grep com.purinis.minecrafttimer"
echo ""
echo "You should see a line with a process number."
echo ""

# NOTES POST INSTALLATION

# TO STOP SCRIPT RUNNING, you use this command:
# sudo launchctl unload /Library/LaunchDaemons/com.purinis.minecrafttimer.plist

# TO CHECK IF SCRIPT IS RUNNING:
# sudo launchctl list | grep com.purinis.minecrafttimer

